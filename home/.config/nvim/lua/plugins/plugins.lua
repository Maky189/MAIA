return {

  -- Icons
  {
    "nvim-tree/nvim-web-devicons",
  },

  -- Fuzzy Finder
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },

  -- Debugging (DAP)
  {
    "mfussenegger/nvim-dap",
  },

  -- Formatting / Linting
  {
    "nvimtools/none-ls.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
  },

}