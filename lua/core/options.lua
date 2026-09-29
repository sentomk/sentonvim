local opt = vim.opt  -- 为了更简洁的写法
-- 缩进设置（2 空格）
opt.tabstop = 2       -- 1 个 Tab = 2 个空格
opt.shiftwidth = 2    -- 自动缩进时用 2 空格
opt.expandtab = true  -- Tab 转为空格（避免混合 Tab 和空格）
opt.softtabstop = 2   -- 退格键删除 2 个空格（与 shiftwidth 一致）
opt.autoindent = true -- 自动缩进
opt.smartindent = true -- 智能缩进（如函数、循环等）
-- 行号设置
opt.number = true          -- 显示绝对行号
opt.relativenumber = true  -- 显示相对行号
-- 其他 UI 设置（可选）
opt.signcolumn = "yes"     -- 总是显示标记列（用于 LSP 错误提示等）
opt.cursorline = true      -- 高亮当前行
opt.wrap = false           -- 不自动换行
opt.termguicolors = true   -- 启用真彩色（更好的颜色支持）

opt.clipboard = "unnamedplus"
