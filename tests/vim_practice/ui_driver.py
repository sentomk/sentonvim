"""Minimal stdlib MessagePack RPC driver for real Neovim input and screen tests."""
import os
import select
import struct
import subprocess
import time
import tempfile
import shutil


def pack(value):
    if value is None: return b'\xc0'
    if value is False: return b'\xc2'
    if value is True: return b'\xc3'
    if isinstance(value, int):
        if 0 <= value <= 127: return bytes([value])
        if -32 <= value < 0: return bytes([256 + value])
        return b'\xd3' + struct.pack('>q', value)
    if isinstance(value, str):
        value = value.encode()
        return (bytes([0xa0 + len(value)]) if len(value) < 32 else b'\xdb' + struct.pack('>I', len(value))) + value
    if isinstance(value, (list, tuple)):
        return (bytes([0x90 + len(value)]) if len(value) < 16 else b'\xdd' + struct.pack('>I', len(value))) + b''.join(map(pack, value))
    if isinstance(value, dict):
        return (bytes([0x80 + len(value)]) if len(value) < 16 else b'\xdf' + struct.pack('>I', len(value))) + b''.join(pack(k) + pack(v) for k, v in value.items())
    raise TypeError(value)


class Incomplete(Exception): pass


def unpack(data, pos=0):
    def take(n):
        nonlocal pos
        if len(data) < pos + n: raise Incomplete()
        chunk, pos = data[pos:pos+n], pos+n
        return chunk
    kind = take(1)[0]
    if kind <= 127: return kind, pos
    if kind >= 224: return kind - 256, pos
    if kind in (192, 194, 195): return {192: None, 194: False, 195: True}[kind], pos
    formats = {202:'>f',203:'>d',204:'>B',205:'>H',206:'>I',207:'>Q',208:'>b',209:'>h',210:'>i',211:'>q'}
    if kind in formats:
        fmt = formats[kind]
        return struct.unpack(fmt, take(struct.calcsize(fmt)))[0], pos
    length = None
    category = None
    if 160 <= kind <= 191: length, category = kind - 160, 'str'
    elif 144 <= kind <= 159: length, category = kind - 144, 'array'
    elif 128 <= kind <= 143: length, category = kind - 128, 'map'
    elif kind in (196,197,198,217,218,219,220,221,222,223,199,200,201):
        size = {196:1,197:2,198:4,217:1,218:2,219:4,220:2,221:4,222:2,223:4,199:1,200:2,201:4}[kind]
        length = int.from_bytes(take(size), 'big')
        category = 'str' if kind in (196,197,198,217,218,219) else 'array' if kind in (220,221) else 'map' if kind in (222,223) else 'ext'
    elif 212 <= kind <= 216: length, category = 2 ** (kind - 212), 'ext'
    if category == 'str': return take(length).decode('utf-8', errors='replace'), pos
    if category == 'ext':
        take(1)
        return unpack(take(length))[0], pos
    if category in ('array', 'map'):
        result = []
        for _ in range(length * (2 if category == 'map' else 1)):
            value, pos = unpack(data, pos)
            result.append(value)
        return (dict(zip(result[::2], result[1::2])) if category == 'map' else result), pos
    raise ValueError(hex(kind))


class Nvim:
    def __init__(self, root, width=120, height=36, init='NONE'):
        self.test_dir = tempfile.mkdtemp(prefix='vim-practice-test-')
        env = dict(os.environ, NVIM_LOG_FILE=self.test_dir + '/nvim.log')
        self.proc = subprocess.Popen([shutil.which('nvim') or '/opt/homebrew/bin/nvim', '--embed', '--headless', '-u', init, '-i', 'NONE', '--cmd', 'set noswapfile'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env, cwd=self.test_dir)
        self.buffer, self.sequence, self.responses = b'', 0, {}
        self.grids, self.highlights = {}, {}
        self.notifications = []
        self.call('nvim_ui_attach', width, height, {'ext_linegrid': True, 'rgb': True})
        self.lua("vim.opt.rtp:prepend(...)", root)
        self.call('nvim_command', 'runtime plugin/vim_practice.lua')
        self.lua("require('vim_practice').setup({delay=160,progress_path=...})", self.test_dir + '/progress.json')
        self.call('nvim_command', 'set laststatus=2 showtabline=0 noshowmode')
        self.pump(.08)

    def pump(self, seconds=.04):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            if not select.select([self.proc.stdout], [], [], max(0, end-time.monotonic()))[0]: break
            chunk = os.read(self.proc.stdout.fileno(), 1048576)
            if not chunk: raise RuntimeError('Neovim exited: ' + self.proc.stderr.read().decode())
            self.buffer += chunk
            while self.buffer:
                try: message, consumed = unpack(self.buffer)
                except Incomplete: break
                self.buffer = self.buffer[consumed:]
                if message[0] == 1: self.responses[message[1]] = message[2:]
                elif message[0] == 2:
                    if message[1] == 'redraw': self.redraw(message[2])
                    else: self.notifications.append(message)

    def redraw(self, events):
        for event in events:
            name, args = event[0], event[1:]
            for a in args:
                if name == 'grid_resize':
                    grid, width, height = a
                    self.grids[grid] = [[(' ', 0) for _ in range(width)] for _ in range(height)]
                elif name == 'grid_clear':
                    grid = self.grids[a[0]]
                    for row in grid: row[:] = [(' ', 0)] * len(row)
                elif name == 'grid_line':
                    grid, row, col, cells = a[:4]
                    hl = 0
                    for cell in cells:
                        if len(cell) > 1: hl = cell[1]
                        repeat = cell[2] if len(cell) > 2 else 1
                        for _ in range(repeat):
                            self.grids[grid][row][col] = (cell[0], hl)
                            col += 1
                elif name == 'grid_scroll':
                    grid, top, bottom, left, right, rows, cols = a
                    original = [r[:] for r in self.grids[grid]]
                    for r in range(top, bottom):
                        for c in range(left, right):
                            source_r, source_c = r + rows, c + cols
                            self.grids[grid][r][c] = original[source_r][source_c] if top <= source_r < bottom and left <= source_c < right else (' ', 0)
                elif name == 'hl_attr_define': self.highlights[a[0]] = a[1]
                elif name == 'default_colors_set': self.default_fg, self.default_bg = a[:2]

    def call(self, method, *args):
        self.sequence += 1
        ident = self.sequence
        self.proc.stdin.write(pack([0, ident, method, list(args)]))
        self.proc.stdin.flush()
        deadline = time.monotonic() + 8
        while ident not in self.responses:
            self.pump(.01)
            if time.monotonic() > deadline: raise TimeoutError(method)
        error, result = self.responses.pop(ident)
        if error: raise RuntimeError(f'{method}: {error}')
        return result

    def lua(self, script, *args): return self.call('nvim_exec_lua', script, list(args))
    def keys(self, keys, wait=.06):
        self.call('nvim_input', keys)
        self.pump(wait)
    def command(self, command, wait=.06): self.keys(':' + command + '<CR>', wait)
    def state(self): return self.lua("local s=require('vim_practice').state(); return s and {id=s.lesson and s.lesson.id, stage=s.stage, passed=s.passed, auto=s.auto, index=s.index, status=s.status, work=s.work_buf, guide=s.guide_buf, win=s.work_win, tab=s.tab} or {}")
    def screen(self):
        self.pump(.02)
        return '\n'.join(''.join(c[0] for c in row) for row in self.grids[1])
    def screenshot(self, path):
        from PIL import Image, ImageDraw, ImageFont
        font = ImageFont.truetype('/System/Library/Fonts/Monaco.ttf', 17)
        cjk = ImageFont.truetype('/System/Library/Fonts/STHeiti Light.ttc', 18)
        grid = self.grids[1]
        width, height = 11, 24
        bg = getattr(self, 'default_bg', 0x14161b)
        fg = getattr(self, 'default_fg', 0xe0e2ea)
        def color(n): return '#' + format(n if n >= 0 else 0, '06x')
        image = Image.new('RGB', (len(grid[0]) * width, len(grid) * height), color(bg))
        draw = ImageDraw.Draw(image)
        for r, row in enumerate(grid):
            for c, (text, hid) in enumerate(row):
                hl = self.highlights.get(hid, {})
                foreground, background = hl.get('foreground', fg), hl.get('background', bg)
                if hl.get('reverse'): foreground, background = background, foreground
                draw.rectangle((c*width, r*height, (c+1)*width, (r+1)*height), fill=color(background))
            for c, (text, hid) in enumerate(row):
                if not text or text == ' ': continue
                hl = self.highlights.get(hid, {})
                foreground = hl.get('background', bg) if hl.get('reverse') else hl.get('foreground', fg)
                draw.text((c*width, r*height+1), text, font=cjk if ord(text[0]) > 127 else font, fill=color(foreground))
        image.save(path)
    def close(self):
        self.proc.terminate()
        self.proc.wait(timeout=5)
        shutil.rmtree(self.test_dir)
