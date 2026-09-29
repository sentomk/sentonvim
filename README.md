# sentonvim

个人 Neovim 配置，包含代码补全、语言服务、文件和内容搜索、注释、C++ 文档查询及 Vim 练习台。默认使用 TokyoNight Moon 主题、2 空格缩进（Tab 转空格）和系统剪贴板。

## 安装

### 1. 准备工具

- **Neovim 0.11.3 或更新版本**：当前 LSP 配置使用 `vim.lsp.config` / `vim.lsp.enable`。
- **Git**：下载配置和插件。
- **C 编译器、curl、tar、unzip**：Treesitter 解析器编译及插件/语言服务器安装时使用。
- **ripgrep**（`rg`）：Telescope 全文搜索需要；**fd** 用于更快的文件搜索，可选。
- **cppman**：C++ 标准库文档查询需要。
- **Nerd Font**：终端中正确显示文件图标，可选。

macOS 已安装 Homebrew 时：

```sh
brew install neovim git ripgrep fd cppman
# 若尚未安装 Apple 命令行开发工具：
xcode-select --install
```

Linux 请用发行版的软件包管理器准备上述工具，并确认 `nvim --version` 满足版本要求。系统剪贴板还需要相应提供程序，例如 Wayland 的 `wl-copy` / `wl-paste` 或 X11 的 `xclip`；macOS 使用系统的 `pbcopy` / `pbpaste`。

### 2. 安装配置

```sh
git clone https://github.com/sentomk/sentonvim.git "$HOME/code/sentonvim"
cd "$HOME/code/sentonvim"
./install.sh --dry-run  # 可选：先查看将操作的位置
./install.sh
nvim
```

`install.sh` 将当前仓库软链接到 `${XDG_CONFIG_HOME:-$HOME/.config}/${NVIM_APPNAME:-nvim}`，默认就是 `~/.config/nvim`。路径包含空格也可使用。

- 已有配置目录、文件或软链接会先移至旁边的 `nvim.backup.时间戳`，脚本会显示确切位置。
- 如果目标已指向本仓库，或本仓库本身就在目标位置，重复执行不会修改它。
- 仓库不能放在需要被替换的旧配置目录内部；安装后也不要移动仓库，否则软链接会失效。
- 脚本只配置目录，不安装系统软件、不修改 shell 配置，不清空 Neovim 的插件、缓存或练习进度。
- 首次启动需要联网：配置会引导安装 lazy.nvim 和缺失插件；等待 `:Lazy` 中任务完成，再重启 Neovim。`lazy-lock.json` 记录插件版本，恢复这些版本可运行 `:Lazy restore`。

自定义配置位置时，安装和启动 Neovim 必须使用一致的环境变量，例如：

```sh
NVIM_APPNAME=sentonvim ./install.sh
NVIM_APPNAME=sentonvim nvim
```

撤销安装：先确认目标确实是脚本创建的软链接，移除该链接，再将脚本输出的备份路径移回原位；不要删除仓库或备份。其他程序使用同一配置目录时，请先退出它们再安装或恢复。

### 3. 检查语言服务

运行 `:checkhealth` 检查环境，`:checkhealth vim.lsp` 检查 LSP；`:Mason` 用于安装和管理语言服务器。

| 语言 | 已启用的配置 | 需要的程序 |
| --- | --- | --- |
| C / C++ / Objective-C | `clangd` | `clangd`，可来自系统工具链或 Mason |
| Rust | `rust_analyzer` | `rust-analyzer`，以及项目需要的 Rust 工具链 |
| Lua | `lua_ls` | `lua-language-server` |

“已启用配置”不代表新机器已经安装对应程序。打开相关文件后，`:lua vim.print(vim.lsp.get_clients({ bufnr = 0 }))` 可查看连接到当前缓冲区的客户端。

C++ 项目建议在项目根目录提供 `compile_commands.json`，让 clangd 获取真实的编译参数和头文件路径。例如 CMake 项目可以开启 `-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`，再将生成的文件链接到项目根目录。当前配置还以 `.clangd`、`.git` 识别项目根目录，并启用了后台索引和 clang-tidy。

## 插件与本地功能

| 插件 / 功能 | 作用 | 配置位置 |
| --- | --- | --- |
| lazy.nvim | 插件引导安装、加载、更新及版本锁定；入口 `:Lazy` | `lua/core/lazy.lua`、`init.lua` |
| tokyonight.nvim | TokyoNight Moon 配色 | `lua/plugins/ui.lua` |
| lualine.nvim | 底部状态栏 | `lua/plugins/ui.lua` |
| nvim-web-devicons | 文件类型图标，供状态栏和其他界面使用 | `lua/plugins/ui.lua` |
| dashboard-nvim | 启动页面 | `lua/plugins/ui.lua` |
| telescope.nvim | 搜索文件、文本、缓冲区、帮助、命令和快捷键 | `lua/plugins/telescope.lua` |
| plenary.nvim | Telescope 依赖的 Lua 工具库，无单独快捷键 | Telescope 的依赖 |
| nvim-treesitter | 语法高亮、语法节点选择、缩进和折叠；自动安装 PHP、C++、Rust、Lua、Java 解析器 | `lua/plugins/treesitter.lua` |
| blink.cmp | 当前主要补全界面：LSP、路径、代码片段、缓冲区内容和函数签名 | `lua/plugins/lsp.lua` |
| friendly-snippets | 为补全提供代码片段 | Blink 的依赖 |
| cmp-nvim-lsp | 生成提供给语言服务器的补全能力信息 | `lua/plugins/lsp.lua` |
| nvim-cmp | 现有配置中保留的补全插件，未单独配置来源或快捷键；日常补全由 Blink 配置 | `lua/plugins/lsp.lua` |
| nvim-lspconfig | 提供 clangd、Rust、Lua 等语言服务器的默认配置 | `lua/plugins/lsp.lua` |
| mason.nvim | 安装和管理语言服务器等开发工具；入口 `:Mason` | `lua/plugins/lsp.lua` |
| mason-lspconfig.nvim | Mason 与 nvim-lspconfig 的集成；语言启用由当前配置显式设置 | `lua/plugins/lsp.lua` |
| trouble.nvim | 集中展示诊断错误和警告 | `lua/plugins/lsp.lua` |
| Comment.nvim | 行注释、块注释及选区注释 | `lua/plugins/comments.lua` |
| nvim-autopairs | 插入模式自动补齐括号、引号等配对符号 | `lua/plugins/autopairs.lua` |
| markdown-preview.nvim | 在浏览器中实时预览 Markdown | `lua/plugins/markdown-preview.lua` |
| cppman 本地集成 | 异步查询 C++ 标准库文档，在独立窗口阅读；需要外部 `cppman` | `plugin/cppman.lua` |
| Vim Practice 本地练习台 | 122 道题、19 个专题，任务和目标常驻，完成后自动下一题 | `plugin/vim_practice.lua`、`lua/vim_practice/` |
| Otty 文件支持 | Otty 文件识别和语法高亮 | `ftdetect/otty.vim`、`syntax/otty.vim` |

Telescope 配置中保留了 fzf 选项，但目前没有安装或加载 `telescope-fzf-native.nvim`，因此使用默认搜索排序器。

## 自定义快捷键

**Leader 是空格。** 下文的 `空格 f f` 表示依次按空格、`f`、`f`；未特别标注的都是普通模式。这里只列配置或插件提供的操作，不介绍 Vim 原生编辑按键。

### 搜索与导航

| 快捷键 | 功能 |
| --- | --- |
| `空格 f f` | 按名称查找文件 |
| `空格 f g` | 搜索项目文本，需要 `rg` |
| `空格 f b` | 查找已打开的缓冲区 |
| `空格 f h` | 查找帮助条目 |
| `空格 f r` | 查找最近打开的文件 |
| `空格 f s` | 搜索光标下的词 |
| `空格 f c` | 查找可执行的编辑器命令 |
| `空格 f k` | 查找当前快捷键映射 |

### 注释、C++ 文档与诊断

| 快捷键 | 功能 / 生效位置 |
| --- | --- |
| `空格 c c` | 切换当前行的行注释 |
| `空格 b c` | 切换当前行的块注释 |
| `空格 c` + 范围动作 | 对指定范围切换行注释，例如 `空格 c }` |
| `空格 b` + 范围动作 | 对指定范围切换块注释 |
| 可视模式 `空格 c` / `空格 b` | 对选区切换行注释 / 块注释 |
| `空格 c m` | cppman 查询光标下的名称 |
| `空格 c s` | 输入名称查询 cppman，例如 `std::thread` |
| `空格 c h` | clangd 已连接时切换对应的头文件 / 源文件 |
| `空格 x x` | 打开 / 关闭 Trouble 诊断列表 |
| 代码中的 `K` | LSP 已连接并支持 hover 时显示类型和文档提示 |
| cppman 窗口中的 `K` | 查询光标下的文档名称 |
| cppman 窗口中的 `q` | 关闭该窗口 |

cppman 也可直接运行 `:Cppman std::thread`，或用 `:Cppman` 输入查询。首次打开某页需要网络，已获取的页面由 cppman 缓存。**输入查询使用 `空格 c s`，避免覆盖 Comment.nvim 的 `空格 c c`。**

格式化映射 `空格 c f`（C/C++）、`空格 r f`（Rust）、`空格 l f`（Lua）仍在配置中，但三个 LSP 都显式禁用了格式化能力，且目前未配置替代格式化工具，因此这些映射当前不能用于格式化。启用前需调整 `lua/plugins/lsp.lua`。

### 补全与语法节点选择

| 快捷键 | 生效位置 / 功能 |
| --- | --- |
| `Tab` / `Shift+Tab` | 补全菜单：选择下一项 / 上一项 |
| `↑` / `↓` | 补全菜单：选择上一项 / 下一项 |
| `Enter` | 补全菜单：接受当前选项 |
| `Ctrl+Space` | Blink：显示补全或切换补全文档 |
| `Ctrl+e` | Blink：取消补全 |
| `Ctrl+b` / `Ctrl+f` | 补全文档向上 / 向下滚动 |
| `Ctrl+k` | 插入模式：显示 / 隐藏函数签名 |
| `Enter` | 普通模式开始 Treesitter 节点选择；选区内继续扩大节点 |
| `Backspace` | Treesitter 选区内缩小节点 |
| `Tab` | Treesitter 选区内扩大到作用域 |

### 本配置的编辑快捷键

| 快捷键 | 功能 |
| --- | --- |
| `Ctrl+s` | 普通模式保存；插入模式先退出再保存 |
| `Ctrl+a` | 普通模式选择全文 |
| 插入模式 `jk` | 退出插入模式 |
| `Ctrl+z` / `Ctrl+y` | 普通或插入模式撤销 / 重做 |

### Vim Practice

用 `:VimPractice` 打开练习台。以下映射仅在练习窗口中使用：

| 快捷键 | 功能 |
| --- | --- |
| `F4` | 选择专题 |
| `F5` | 重置本题 |
| `F7` | 上一题 |
| `F8` | 跳过 / 下一题 |
| `F9` | 暂停 / 恢复自动下一题 |

HHKB 等键盘可以用 `:VimPracticePrev`、`:VimPracticeNext` 等命令。完整说明见 [Vim Practice 文档](doc/vim-practice.md)。

## 常用插件命令与维护

| 命令 | 用途 |
| --- | --- |
| `:Lazy` | 查看插件安装、加载和更新状态 |
| `:Lazy restore` | 将插件恢复至 `lazy-lock.json` 记录的版本 |
| `:Mason` | 安装 / 管理语言服务器与工具 |
| `:TSInstallInfo` | 查看 Treesitter 解析器状态 |
| `:MarkdownPreviewToggle` | 开启 / 关闭当前 Markdown 的浏览器预览 |
| `:Cppman std::future` | 查询标准库文档 |
| `:VimPractice` | 打开练习台 |
| `:checkhealth` | 排查环境问题 |

Markdown 预览目前将浏览器指定为 `google-chrome`；若本机无法通过这个名字启动浏览器，可在 `lua/plugins/markdown-preview.lua` 中调整 `vim.g.mkdp_browser`，或删除该设置使用默认浏览器。插件首次安装会下载预览服务组件；安装失败时先查看 `:Lazy` 构建日志。

修改配置后重启 Neovim。更新插件会改变锁文件；提交配置时也应检查 `lazy-lock.json` 的改动。

安装脚本回归检查（在临时目录运行，不操作真实配置）：

```sh
bash tests/install.sh
```
