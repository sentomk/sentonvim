# sentonvim

面向日常代码编辑的个人 Neovim 配置，主要用于 C/C++，同时配置了 Rust 和 Lua 语言服务。

- **编辑**：2 空格缩进、系统剪贴板、相对行号；搜索忽略大小写，输入大写字母时区分大小写。
- **代码**：Blink 补全与参数占位符，LSP 跳转、重命名、诊断和手动格式化。
- **查找**：Telescope 搜索文件、项目文本和符号，netrw 浏览目录。
- **界面**：TokyoNight Moon 主题、lualine 状态栏。换行格式显示为 `LF` / `CRLF` / `CR`。
- **学习**：cppman 标准库文档查询，以及独立的 Vim Practice 练习台。

## 安装

### 环境准备

需要 Neovim **0.11.3 或更新版本**、Git，以及用于插件安装和 Treesitter 解析器编译的 C 编译器、curl、tar、unzip。

| 工具 | 用途 |
| --- | --- |
| `ripgrep`（`rg`） | 项目文本搜索 |
| `fd` | 加快文件搜索，可选 |
| `cppman` | C++ 标准库文档查询 |
| Nerd Font | 正确显示状态栏等位置的图标，可选 |

macOS 使用 Homebrew 安装：

```sh
brew install neovim git ripgrep fd cppman
```

如果还没有 Apple 命令行开发工具，运行 `xcode-select --install`。Linux 使用发行版的软件包管理器安装依赖；系统剪贴板还需要 Wayland 的 `wl-copy` / `wl-paste` 或 X11 的 `xclip` 等提供程序。macOS 使用自带的 `pbcopy` / `pbpaste`。

### 安装配置

```sh
git clone https://github.com/sentomk/sentonvim.git "$HOME/code/sentonvim"
cd "$HOME/code/sentonvim"
./install.sh --dry-run
./install.sh
nvim
```

安装脚本将当前仓库软链接到 `~/.config/nvim`。已有配置会移到旁边的带时间戳备份目录；如果目标已经指向本仓库，重复执行不会修改它。

脚本只配置目录，外部工具需要自行安装。首次启动 Neovim 时，lazy.nvim 会联网安装插件；等待安装完成后重启，并运行 `:checkhealth`。

<details>
<summary>自定义安装位置与恢复备份</summary>

目标路径为 `${XDG_CONFIG_HOME:-$HOME/.config}/${NVIM_APPNAME:-nvim}`。使用其他配置名称时，安装和启动需要设置相同的变量：

```sh
NVIM_APPNAME=sentonvim ./install.sh
NVIM_APPNAME=sentonvim nvim
```

仓库应放在将被替换的配置目录之外，安装后也不要移动仓库，以免软链接失效。

恢复旧配置时，先退出 Neovim，确认目标是脚本创建的软链接，再移除该链接，将脚本输出的备份路径移回原位。脚本不会清空插件、缓存或练习进度。

</details>

### 语言服务器

配置会启用下列语言服务，但需要先通过 `:Mason` 或系统工具链安装对应程序。Mason 安装的工具会加入 Neovim 的搜索路径。

| 语言 | LSP 配置名 | 所需程序 |
| --- | --- | --- |
| C / C++ / Objective-C | `clangd` | `clangd` |
| Rust | `rust_analyzer` | `rust-analyzer`，以及项目所需的 Rust 工具链 |
| Lua | `lua_ls` | `lua-language-server` |

打开源文件后，用 `:checkhealth vim.lsp` 检查状态。查看当前文件连接的语言服务器：

```vim
:lua vim.print(vim.lsp.get_clients({ bufnr = 0 }))
```

## C++ 项目配置

### 编译参数与语言标准

clangd 启用了后台索引、clang-tidy 和参数占位符。配置不会强制指定 C++ 标准；项目应提供 `compile_commands.json`，让 clangd 读取实际的编译参数和头文件路径。

CMake 项目可在配置时启用 `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`（使用支持此选项的 Ninja 或 Makefile 生成器）。如果文件生成在构建目录中，可将它链接到项目根目录。

单文件练习可以在练习目录创建 `.clangd`：

```yaml
CompileFlags:
  Add: [-std=c++20]
```

`.clangd` 影响编辑器解析；实际编译命令也要使用相同标准。

### 缩进与格式化

- 输入时：C/C++ 使用 Neovim 内置 `cindent`，每级 2 空格。
- 格式化：按 `空格 c f` 调用 clangd，格式由项目 `.clang-format` 决定。
- 保存时：不会自动格式化。

希望格式化也使用 2 空格时，可以在项目根目录创建 `.clang-format`：

```yaml
BasedOnStyle: LLVM
IndentWidth: 2
```

## 快捷键

**Leader 是空格。** `空格 c f` 表示依次按空格、`c`、`f`。除特别说明外均为普通模式。这里只列本配置或插件提供的映射，以及被本配置改变的原生按键。

### 编辑与窗口

| 按键 | 操作 |
| --- | --- |
| `空格 w` / `Ctrl+s` | 保存文件 |
| 插入模式 `Ctrl+s` | 退出插入模式并保存 |
| 插入模式 `jk` | 退出插入模式 |
| `Ctrl+d` / `Ctrl+u` | 向下 / 向上翻半页，并将光标所在行居中 |
| `空格 /` | 清除搜索高亮 |
| `空格 e` | 使用 netrw 浏览目录 |

新分屏默认向右或向下打开。状态栏的 `LF` / `CRLF` / `CR` 表示文件换行格式，不表示操作系统。

### 搜索与代码导航

| 按键 | 操作 |
| --- | --- |
| `空格 f f` | 按名称查找文件 |
| `空格 f g` | 搜索项目文本，需要 `rg` |
| `空格 f s` | 搜索光标下的词 |
| `空格 f b` | 查找已打开的缓冲区 |
| `空格 f r` | 查找最近打开的文件 |
| `空格 f h` | 查找帮助条目 |
| `空格 f c` | 查找编辑器命令 |
| `空格 f k` | 查找快捷键映射 |
| `空格 f d` | 查找当前文件的符号，需要 LSP |
| `gd` / `gr` / `gi` | 跳转定义 / 查找引用 / 跳转实现，需要 LSP |

### 代码操作与诊断

以下代码操作依赖当前文件的语言服务器支持。C++、Rust 和 Lua 使用相同的快捷键。

| 按键 | 操作 |
| --- | --- |
| `空格 c f` | 格式化文件；可视模式下格式化选区 |
| `空格 c r` | 重命名符号 |
| `空格 c a` | 代码操作，也支持可视模式选区 |
| `K` | 查看类型和文档提示 |
| `空格 c d` | 查看当前位置的诊断详情 |
| `空格 x x` | 打开 / 关闭 Trouble 诊断列表 |
| `空格 c h` | 切换对应的头文件 / 源文件，仅 clangd |

### 注释与文档

| 按键 | 操作 |
| --- | --- |
| `空格 c c` | 切换当前行的行注释 |
| `空格 b c` | 切换当前行的块注释 |
| `gc` / `gb` + 范围动作 | 对指定范围切换行注释 / 块注释 |
| 可视模式 `gc` / `gb` | 对选区切换行注释 / 块注释 |
| `空格 c m` | 用 cppman 查询光标下的名称 |
| `空格 c s` | 输入名称查询 cppman，例如 `std::thread` |
| cppman 窗口中的 `K` / `q` | 继续查询光标下的名称 / 关闭文档窗口 |

也可以运行 `:Cppman std::thread`。首次获取文档需要网络，已获取的页面由 cppman 缓存。

### 补全与参数填写

补全使用 Blink 的 `super-tab` 方案。候选不会自动选中，移动选择也不会修改正文。日常操作无需方向键。

| 按键 | 操作 |
| --- | --- |
| `Ctrl+n` / `Ctrl+p` | 选择下一项 / 上一项候选 |
| `Tab` | 确认候选，或跳到下一参数；无候选和片段时正常缩进 |
| `Shift+Tab` | 跳到上一参数 |
| `Enter` | 确认已选中的候选；未选中时正常换行 |
| `Ctrl+Space` | 显示补全列表或切换补全文档 |
| `Ctrl+e` | 关闭补全列表 |
| `Ctrl+b` / `Ctrl+f` | 向上 / 向下滚动补全文档 |
| `Ctrl+k` | 显示 / 隐藏函数签名 |

以 clangd 提供的 `std::vector` 模板补全为例：输入 `std::vec`，列表出现后按 `Tab` 确认首项；输入 `int` 替换选中的占位符，再按 `Tab` 跳出。

填写参数期间，如果又弹出候选列表，**未主动选择候选时，`Tab` 继续跳参数**；用 `Ctrl+n/p` 选中候选后，`Tab` 确认该候选。参数占位符的内容由语言服务器提供。

### 语法节点选择

| 按键 | 操作 |
| --- | --- |
| 普通模式 `Enter` | 开始 Treesitter 节点选择 |
| 节点选区中的 `Enter` | 扩大到上一层节点 |
| 节点选区中的 `Backspace` | 缩小到上一选区 |
| 节点选区中的 `Tab` | 扩大到作用域 |

### Vim Practice

运行 `:VimPractice` 打开练习台。任务说明和目标常驻，完成后自动进入下一题。以下按键仅在练习窗口中使用：

| 按键 | 操作 |
| --- | --- |
| `F4` | 选择专题 |
| `F5` | 重置本题 |
| `F7` | 上一题 |
| `F8` | 跳过 / 下一题 |
| `F9` | 暂停 / 恢复自动下一题 |

HHKB 等键盘也可使用 `:VimPracticePrev`、`:VimPracticeNext` 等命令。完整说明见 [Vim Practice 文档](doc/vim-practice.md)。

## 插件与配置位置

| 插件 | 用途 | 配置文件 |
| --- | --- | --- |
| lazy.nvim | 插件安装、加载和版本锁定 | [core/lazy.lua](lua/core/lazy.lua)、[init.lua](init.lua) |
| blink.cmp | LSP、路径、片段、缓冲区补全及函数签名 | [completion.lua](lua/plugins/completion.lua) |
| friendly-snippets | 代码片段库 | Blink 的依赖 |
| nvim-lspconfig | 语言服务器默认配置 | [lsp.lua](lua/plugins/lsp.lua) |
| mason.nvim | 安装、管理语言服务器和工具 | [lsp.lua](lua/plugins/lsp.lua) |
| trouble.nvim | 诊断列表 | [lsp.lua](lua/plugins/lsp.lua) |
| telescope.nvim | 文件、文本、符号等搜索 | [telescope.lua](lua/plugins/telescope.lua) |
| plenary.nvim | Telescope 使用的 Lua 工具库 | Telescope 的依赖 |
| nvim-treesitter | 语法高亮、节点选择、折叠和缩进；C/C++ 使用内置缩进 | [treesitter.lua](lua/plugins/treesitter.lua) |
| Comment.nvim | 行注释和块注释 | [comments.lua](lua/plugins/comments.lua) |
| nvim-autopairs | 自动补齐括号、引号 | [autopairs.lua](lua/plugins/autopairs.lua) |
| markdown-preview.nvim | 使用默认浏览器预览 Markdown | [markdown-preview.lua](lua/plugins/markdown-preview.lua) |
| tokyonight.nvim | TokyoNight Moon 配色 | [ui.lua](lua/plugins/ui.lua) |
| lualine.nvim | 状态栏 | [ui.lua](lua/plugins/ui.lua) |
| nvim-web-devicons | 文件类型图标 | lualine 的依赖 |

Treesitter 自动安装 C、C++、Rust、Lua、PHP、Java 解析器；语法支持与 LSP 支持分别配置。

本地功能与基础选项：

| 文件 | 用途 |
| --- | --- |
| [core/options.lua](lua/core/options.lua) | 缩进、搜索、剪贴板和窗口选项 |
| [core/keymaps.lua](lua/core/keymaps.lua) | 全局快捷键 |
| [plugin/cppman.lua](plugin/cppman.lua) | 异步 C++ 文档查询 |
| [lua/vim_practice/](lua/vim_practice/) | Vim Practice 练习内容和界面 |
| [ftdetect/otty.vim](ftdetect/otty.vim)、[syntax/otty.vim](syntax/otty.vim) | Otty 文件识别和高亮 |

`lua/plugins/` 中的模块由 lazy.nvim 自动发现。

## 维护与排查

| 命令 | 用途 |
| --- | --- |
| `:Lazy` | 查看插件安装、加载、更新及清理状态 |
| `:Lazy restore` | 恢复 `lazy-lock.json` 锁定的插件版本 |
| `:Mason` | 安装、管理语言服务器和工具 |
| `:TSInstallInfo` | 查看 Treesitter 解析器状态 |
| `:MarkdownPreviewToggle` | 开启 / 关闭当前 Markdown 的浏览器预览 |
| `:checkhealth` | 检查依赖和运行环境 |
| `:checkhealth vim.lsp` | 检查语言服务 |

- **没有语义补全或跳转**：确认语言服务器已安装并连接到当前文件，再检查项目编译参数。
- **C++ 头文件找不到或标准不匹配**：检查 `compile_commands.json` 和 `.clangd`。
- **格式化结果与输入缩进不同**：检查项目 `.clang-format`；缩进设置和格式化设置是两套规则。
- **Markdown 预览无法启动**：查看 `:Lazy` 构建日志；插件安装时需要下载预览服务组件。

修改配置后重启 Neovim。更新插件会改变 `lazy-lock.json`，提交前一起检查。

### 回归检查

在仓库根目录运行；测试使用临时目录和独立 Neovim 实例：

```sh
bash tests/install.sh
python3 tests/completion.py
python3 tests/cpp_indent.py
python3 tests/vim_practice/test_ui.py "$PWD" "$PWD/init.lua"
```

Python 测试使用标准库。补全测试需要 `clangd` 和可用的 C++ 标准库头文件；使用完整配置的测试需要先安装插件。
