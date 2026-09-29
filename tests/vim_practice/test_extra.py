"""Verify added editing lessons using the exact native keys described in their hints."""
import sys
sys.dont_write_bytecode = True
import json
from pathlib import Path
from ui_driver import Nvim
root = sys.argv[1] if len(sys.argv) > 1 else str(next(p for p in Path(__file__).resolve().parents if (p / 'plugin/vim_practice.lua').exists()))
init = sys.argv[2] if len(sys.argv) > 2 else 'NONE'
cases = json.loads((Path(__file__).parent / 'extra_solutions.json').read_text())
n = Nvim(root, width=80, height=24, init=init)
try:
    n.lua("vim.opt.clipboard = ''")
    for category in ['edit', 'objects']:
        n.command('VimPractice ' + category)
        if n.state()['auto']: n.keys('<F9>')
        for _ in range(5): n.keys('<F8>')
        for case in [c for c in cases if c['category'] == category]:
            assert n.state()['id'] == case['id'], (case['id'], n.state())
            visible = n.lua("local s=require('vim_practice').state(); return vim.api.nvim_buf_line_count(s.guide_buf) <= vim.api.nvim_win_get_height(s.guide_win)-1")
            assert visible, 'Task or target clipped at 80x24: ' + case['id']
            commands = case['keys'] if isinstance(case['keys'], list) else [case['keys']]
            for keys in commands: n.keys(keys)
            if not n.state()['passed']:
                print(n.screen())
                print(n.lua("local s=require('vim_practice').state(); return {actual=vim.api.nvim_buf_get_lines(s.work_buf,0,-1,false),expected=s.lesson.target,start=s.lesson.start}"))
                raise AssertionError('Hint does not solve ' + case['id'])
            n.keys('<F8>')
        assert n.state().get('id') is None, 'Topic should finish after its added lessons'
    print(f'PASS: {len(cases)} lesson hints solved with real keys; all task/target panes visible at 80x24')
finally:
    n.close()
