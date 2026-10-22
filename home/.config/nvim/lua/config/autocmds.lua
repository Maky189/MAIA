-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Force-disable every diagnostic visual (no underlines, virtual text, or signs).
-- This runs after LazyVim has set up the LSP, so it reliably wins over the
-- defaults. Treesitter syntax highlighting is untouched.
local function disable_diagnostics()
  vim.diagnostic.config({
    underline = false,
    virtual_text = false,
    signs = false,
    update_in_insert = false,
  })
  -- Fully off: also hides the statusline counts and the red dots in the file tree.
  vim.diagnostic.enable(false)
end
vim.api.nvim_create_autocmd("User", { pattern = "VeryLazy", callback = disable_diagnostics })
vim.api.nvim_create_autocmd("LspAttach", { callback = disable_diagnostics })

-- Persist the chosen colorscheme across sessions.
-- Saves whenever the colorscheme changes; it is loaded back on startup in
-- lua/plugins/colorscheme.lua. Pick a theme however you like (e.g. <leader>uC)
-- and it will be remembered next time you open nvim.
local colorscheme_state = vim.fn.stdpath("state") .. "/last_colorscheme"
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("persist_colorscheme", { clear = true }),
  callback = function(ev)
    local name = ev.match or vim.g.colors_name
    -- Only plain colorscheme names (never a path), so a bad value can't stick.
    if not name or not name:match("^[%w%-_]+$") then
      return
    end
    local fd = io.open(colorscheme_state, "w")
    if fd then
      fd:write(name)
      fd:close()
    end
  end,
})

-- Keep everything see-through like the editor, whatever colorscheme is active.
-- Catppuccin's `transparent_background` only covers the editor, so floats and
-- sidebars (Claude/Codex terminals, pickers, popups) get their background
-- stripped here, after each colorscheme load. Text and borders keep their colours.
local transparent_groups = {
  "Normal", "NormalNC", "NormalFloat", "FloatBorder", "FloatTitle",
  "SignColumn", "EndOfBuffer", "WinBar", "WinBarNC",
  "SnacksNormal", "SnacksNormalNC", "SnacksWinBar", "SnacksWinBarNC",
  "SnacksBackdrop", "SnacksPicker", "SnacksPickerBorder", "SnacksTerminal",
}
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("transparent_floats", { clear = true }),
  callback = function()
    for _, g in ipairs(transparent_groups) do
      local hl = vim.api.nvim_get_hl(0, { name = g, link = false })
      hl.bg = nil
      hl.ctermbg = nil
      vim.api.nvim_set_hl(0, g, hl)
    end
  end,
})
-- The colorscheme may already be loaded before this file runs.
vim.schedule(function()
  vim.api.nvim_exec_autocmds("ColorScheme", { modeline = false })
end)
