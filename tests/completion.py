"""Exercise completion with real C++ LSP responses and Neovim input."""
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True
root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1])
sys.path.insert(0, str(root / 'tests/vim_practice'))
from ui_driver import Nvim

n = Nvim(str(root), init=str(root / 'init.lua'))

def wait_for(check, message, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = check()
        if value:
            return value
        n.pump(.05)
    raise AssertionError(message + ': ' + repr(state()))

def state():
    return n.lua("""local c = require('blink.cmp')
      local items = {}
      for _, i in ipairs(c.get_items()) do
        items[#items+1] = { label=i.label, format=i.insertTextFormat,
          text=i.textEdit and i.textEdit.newText or i.insertText, source=i.source_id }
      end
      return {line=vim.api.nvim_get_current_line(), cursor=vim.api.nvim_win_get_cursor(0),
        mode=vim.fn.mode(), visible=c.is_visible(), idx=c.get_selected_item_idx() or 0,
        active=vim.snippet.active(), items=items}
    """)

def reset(prefix):
    n.keys('<Esc>')
    n.lua("""require('blink.cmp').cancel(); vim.snippet.stop()
      vim.api.nvim_buf_set_lines(0, 5, 6, false, {'  '})
      vim.api.nvim_win_set_cursor(0, {6, 2})""")
    n.pump(.1)
    n.keys('A' + prefix, .15)

try:
    Path(n.test_dir, '.clangd').write_text('CompileFlags:\n  Add: [-std=c++17]\n')
    source = Path(n.test_dir, 'completion.cpp')
    source.write_text('#include <vector>\nvoid reserve_jobs(int count, bool eager); void dispatch_one(int count); void dispatch_two(bool eager);\n'
                      'int main() {\n  int sentocompletion_alpha = 0;\n'
                      '  int sentocompletion_beta = 0;\n  \n}\n')
    n.call('nvim_command', 'edit ' + str(source))
    wait_for(lambda: n.lua("local c=vim.lsp.get_clients({bufnr=0,name='clangd'})[1]; return c and c.initialized"), 'clangd did not attach')
    # Wait for the AST so clangd does not offer identifier-only fallback items.
    n.lua("""local c = vim.lsp.get_clients({bufnr=0,name='clangd'})[1]
      local r, err = c:request_sync('textDocument/documentSymbol',
        {textDocument={uri=vim.uri_from_bufnr(0)}}, 5000, 0)
      assert(r and r.result, vim.inspect(err or r))""")

    reset('std::vec')
    wait_for(lambda: state()['visible'] and state()['items'] and state()['items'][0]['format'] == 2, 'template snippet not offered')
    assert state()['idx'] == 0 and state()['line'] == '  std::vec', state()
    n.keys('<Tab>', .2)
    assert state()['active'] and state()['mode'].startswith('s'), state()
    n.keys('int', .15)
    assert state()['line'] == '  std::vector<int>', state()
    n.keys('<Tab>', .15)
    assert state()['cursor'][1] == len(state()['line']), state()
    print('PASS: Tab expands template placeholder, typing replaces it, Tab exits without duplicate brackets')

    reset('dispatch_')
    wait_for(lambda: state()['visible'] and len(state()['items']) >= 2, 'function candidates missing')
    n.keys('<C-n>', .1)
    assert state()['idx'] == 1 and state()['line'] == '  dispatch_', state()
    n.keys('<C-n>', .1)
    assert state()['idx'] == 2 and state()['line'] == '  dispatch_', state()
    n.keys('<C-p>', .1)
    assert state()['idx'] == 1, state()
    n.keys('<C-e>', .1)
    assert not state()['visible'] and state()['line'] == '  dispatch_', state()
    print('PASS: Ctrl+n/p cycles without editing text; cancellation preserves prefix')

    reset('reserve_jo')
    wait_for(lambda: state()['visible'] and state()['items'] and 'reserve_jobs' in state()['items'][0]['label'], 'function missing')
    n.keys('<Tab>', .2)
    assert state()['active'] and state()['mode'].startswith('s'), state()
    n.keys('sentocompletion_', .2)
    wait_for(lambda: state()['visible'] and len(state()['items']) >= 2, 'argument completions missing')
    assert state()['idx'] == 0, state()
    n.keys('<Tab>', .15)
    assert state()['mode'].startswith('s') and 'sentocompletion_' in state()['line'], state()
    n.keys('<S-Tab>', .15)
    n.keys('2', .1)
    n.keys('<Tab>', .15)
    n.keys('true', .1)
    n.keys('<Tab>', .15)
    assert state()['line'] == '  reserve_jobs(2, true)', state()
    assert state()['cursor'][1] == len(state()['line']), state()
    print('PASS: unselected popup does not steal Tab from arguments; forward/backward replacement works')

    reset('reserve_jo')
    wait_for(lambda: state()['visible'] and state()['items'] and 'reserve_jobs' in state()['items'][0]['label'], 'function missing')
    n.keys('<Tab>', .2)
    n.keys('sentocompletion_', .2)
    wait_for(lambda: state()['visible'] and len(state()['items']) >= 2, 'argument completions missing')
    n.keys('<C-n>', .1)
    label = state()['items'][0]['label'].strip()
    n.keys('<Tab>', .15)
    assert label in state()['line'] and state()['active'], state()
    n.keys('<Tab>', .15)
    assert state()['mode'].startswith('s'), state()
    print('PASS: explicitly selected argument candidate is accepted before moving to next parameter')

    reset('sentocompletion_')
    wait_for(lambda: state()['visible'] and len(state()['items']) >= 2, 'plain candidates missing')
    n.keys('<C-n>', .1)
    label = state()['items'][0]['label'].strip()
    n.keys('<CR>', .15)
    assert state()['line'] == '  ' + label, state()
    reset('sentocompletion_')
    wait_for(lambda: state()['visible'] and state()['items'], 'plain candidates missing')
    n.keys('<CR>', .15)
    assert n.lua('return vim.api.nvim_buf_get_lines(0, 5, 6, false)[1]') == '  sentocompletion_', state()
    print('PASS: Enter accepts a selected item and otherwise inserts a newline')

    reset('')
    n.keys('<Tab>', .1)
    assert state()['line'] == '    ', state()
    print('PASS: Tab without a menu or snippet indents')
finally:
    n.close()
