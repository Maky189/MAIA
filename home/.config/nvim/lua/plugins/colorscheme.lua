-- Default theme: Tokyo Night (night), with strong per-token colours (functions, types,
-- keywords, strings) and a transparent background to match the kitty blur.
-- Catppuccin Mocha stays installed as an alternative (pick it with <leader>uC).
-- The last colorscheme you pick (<leader>uC) is remembered; see lua/config/autocmds.lua.
return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = {
      style = "night",
      transparent = true,
      terminal_colors = true,
      styles = {
        comments = { italic = true },
        keywords = { italic = false },
        functions = {},
        variables = {},
        sidebars = "transparent",
        floats = "transparent",
      },
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = true,
      float = { transparent = true, solid = false },
      term_colors = true,
      dim_inactive = { enabled = false },
      styles = { comments = { "italic" }, conditionals = { "italic" } },
      default_integrations = true,
      integrations = {
        blink_cmp = true,
        gitsigns = true,
        noice = true,
        notify = true,
        snacks = { enabled = true },
        treesitter = true,
        which_key = true,
        mini = { enabled = true },
        native_lsp = { enabled = true },
        telescope = { enabled = true },
        trouble = true,
        flash = true,
        bufferline = true,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = function(_, opts)
      opts.colorscheme = "tokyonight-night" -- default until you pick another one
      local fd = io.open(vim.fn.stdpath("state") .. "/last_colorscheme", "r")
      if fd then
        local name = fd:read("*l")
        fd:close()
        -- Only trust a saved name that is an installed colorscheme.
        if name and name:match("^[%w%-_]+$") and vim.tbl_contains(vim.fn.getcompletion(name, "color"), name) then
          opts.colorscheme = name
        end
      end
    end,
  },
}
