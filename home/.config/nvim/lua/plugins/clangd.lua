-- Point clangd at the CMake compile database (.build/<preset>/), wherever it lives.
return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      clangd = {
        cmd = function(dispatchers, config)
          return require("config.clangd_db").cmd(dispatchers, config)
        end,
      },
    },
  },
}
