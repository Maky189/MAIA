-- Visual polish: cursor trail, nicer statusline/tabs, softer notifications.
return {
  -- Cursor trail (matches kitty's cursor_trail).
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    opts = {
      smear_between_buffers = true,
      smear_between_neighbor_lines = true,
      scroll_buffer_space = true,
      legacy_computing_symbols_support = false,
      smear_insert_mode = true,
      stiffness = 0.8,
      trailing_stiffness = 0.5,
      distance_stop_animating = 0.5,
    },
  },

  -- Statusline: rounded separators, bright but unobtrusive.
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.options = vim.tbl_deep_extend("force", opts.options or {}, {
        theme = "auto",
        globalstatus = true,
        component_separators = { left = "", right = "" },
        section_separators = { left = "", right = "" },
      })
      -- No error/warning counts in the statusline.
      opts.sections = opts.sections or {}
      opts.sections.lualine_c = vim.tbl_filter(function(c)
        return not (type(c) == "table" and c[1] == "diagnostics") and c ~= "diagnostics"
      end, opts.sections.lualine_c or {})
    end,
  },

  -- Buffer tabs: slim, rounded, with no close-button clutter.
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        separator_style = "thin",
        always_show_bufferline = false,
        diagnostics = false,
        show_buffer_close_icons = false,
        show_close_icon = false,
        indicator = { style = "underline" },
      },
    },
  },

  -- Pretty notifications / indent guides / smooth scrolling (all from snacks).
  {
    "folke/snacks.nvim",
    opts = {
      notifier = { style = "compact", timeout = 3000 },
      indent = { animate = { enabled = true, duration = { step = 15, total = 300 } } },
      scroll = { enabled = true },
      words = { enabled = true },
      input = { enabled = true },
      picker = { enabled = true },
      styles = { notification = { wo = { winblend = 12 } } },
    },
  },

  -- Command line / messages / popup menu in the middle of the screen.
  {
    "folke/noice.nvim",
    opts = {
      presets = { bottom_search = false, command_palette = true, long_message_to_split = true, lsp_doc_border = true },
    },
  },

  -- Prettier markdown / AI chat rendering.
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown", "Avante", "codecompanion" },
    opts = { code = { sign = false, width = "block", right_pad = 1 }, heading = { sign = false } },
  },

  -- No red/yellow diagnostic dots in the file explorer.
  {
    "folke/snacks.nvim",
    opts = { picker = { sources = { explorer = { diagnostics = false } } } },
  },
}
