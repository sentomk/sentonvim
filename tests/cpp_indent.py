"""Verify C++ indentation while typing an unfinished constructor."""
import sys
from pathlib import Path
sys.dont_write_bytecode = True
root = Path(sys.argv[1] if len(sys.argv) > 1 else Path(__file__).resolve().parents[1])
sys.path.insert(0, str(root / 'tests/vim_practice'))
from ui_driver import Nvim
n = Nvim(str(root), init=str(root / 'init.lua'))
lines = ['class thread_pool {', 'public:',
         '  explicit thread_pool(std::size_t count) {',
         '    if (count == 0) {',
         '      throw std::invalid_argument("thread count must be positive");',
         '    }', '  }', '};']
def reset(row):
    n.keys('<Esc>')
    n.lua("vim.cmd('enew!'); vim.bo.filetype='cpp'; vim.api.nvim_buf_set_lines(0,0,-1,false,...)", lines)
    n.call('nvim_win_set_cursor', 0, [row, 0])
    assert n.lua("return vim.bo.cindent and vim.bo.indentexpr == '' and vim.bo.shiftwidth == 2")
def line(): return n.lua('return vim.api.nvim_get_current_line()')
try:
    reset(6)
    n.keys('A<CR>workers_.reserve(count);', .3)
    assert line() == '    workers_.reserve(count);', repr(line())
    reset(4)
    n.keys('A<CR>throw count;', .3)
    assert line() == '      throw count;', repr(line())
    reset(6)
    n.keys('oworkers_.reserve(count);', .3)
    assert line() == '    workers_.reserve(count);', repr(line())
    n.keys('<Esc>')
    n.lua("vim.api.nvim_set_current_line('workers_.reserve(count);')")
    n.keys('==')
    assert line() == '    workers_.reserve(count);', repr(line())
    print('PASS: Enter after if block, Enter inside if, o below block, and == repair; 2-space levels')
    lines = ['class thread_pool {', 'public:',
             '  explicit thread_pool(std::size_t count) {',
             '    try {', 'for  () {', '    ', '    }',
             '    } catch (declaration) {', '    ', '    }', '  }', '};']
    reset(5)
    n.keys('==')
    assert line() == '      for  () {', repr(line())
    n.keys('A<CR>run();', .3)
    assert line() == '        run();', repr(line())
    reset(4)
    n.keys('A<CR>', .2)
    assert line() == '      ', repr(line())
    print('PASS: == on unfinished for inside try, loop body indentation, and Enter after try')
finally:
    n.close()
