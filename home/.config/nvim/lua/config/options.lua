-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Silence LazyVim's startup order check and deprecation warnings.
vim.g.lazyvim_check_order = false
vim.g.deprecation_warnings = false

-- Never auto-format / auto-fix code style on save. Format manually with <leader>cf.
vim.g.autoformat = false

-- Clean startup: swallow any notifications emitted before the UI is ready
-- (deprecation / plugin-update / LSP spam). Once snacks.nvim installs its own
-- notifier it replaces this stub, so genuine runtime notifications still work.
-- Use :messages or :Lazy if you ever need to see what happened on startup.
do
  local real_notify = vim.notify
  local function swallow() end
  vim.notify = swallow
  -- Safety net: if nothing replaced our stub shortly after startup, restore it.
  vim.defer_fn(function()
    if vim.notify == swallow then
      vim.notify = real_notify
    end
  end, 3000)
end

-- ── Look & feel ──────────────────────────────────────────────────────────────
-- Plain absolute line numbers: the number column never changes when you move up/down.
vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.numberwidth = 4

vim.opt.cursorline = true
vim.opt.cursorlineopt = "number,line"
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.smoothscroll = true
vim.opt.signcolumn = "yes"
vim.opt.termguicolors = true
vim.opt.pumblend = 12 -- slightly translucent popup menu
vim.opt.winblend = 12 -- slightly translucent floating windows
vim.opt.winborder = "rounded" -- rounded borders on every float
vim.opt.fillchars = { eob = " ", fold = " ", foldopen = "", foldclose = "", diff = "╱" }
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.opt.undofile = true
vim.opt.confirm = true
