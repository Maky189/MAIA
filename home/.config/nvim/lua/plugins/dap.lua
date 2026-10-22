return {
  "mfussenegger/nvim-dap",
  config = function()
    local dap = require("dap")

    dap.adapters.cppdbg = {
      id = "cppdbg",
      type = "executable",
      command = "OpenDebugAD7", -- install via Mason
    }

    -- Extend (not replace) the configs the clangd extra sets up (codelldb), so both work.
    dap.configurations.cpp = vim.list_extend(dap.configurations.cpp or {}, {
      {
        name = "Launch file",
        type = "cppdbg",
        request = "launch",
        program = function()
          return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
        end,
        cwd = "${workspaceFolder}",
        stopAtEntry = false,
      },
    })
    dap.configurations.c = dap.configurations.c or dap.configurations.cpp
  end,
}