-- Finds the compile_commands.json clangd should use for a project.
-- CMake presets put it in .build/<preset>/, which clangd does not search by itself.
-- A project without its own database (e.g. a game that only includes engine headers)
-- borrows the engine's, so its engine includes resolve too.
local M = {}

local ENGINE = vim.fn.expand("~/Projects/TerraFora-Engine")

local function newest(root)
  local best, best_t
  for _, pat in ipairs({ "/compile_commands.json", "/build/compile_commands.json", "/.build/*/compile_commands.json", "/build/*/compile_commands.json", "/out/*/compile_commands.json" }) do
    for _, f in ipairs(vim.fn.glob(root .. pat, true, true)) do
      local st = vim.uv.fs_stat(f)
      local is_linux = f:find("linux", 1, true) and 1e12 or 0 -- prefer the linux preset
      local t = st and (st.mtime.sec + is_linux) or 0
      if not best_t or t > best_t then best, best_t = f, t end
    end
  end
  return best and vim.fs.dirname(best)
end

function M.dir_for(root)
  return (root and newest(root)) or newest(ENGINE)
end

function M.cmd(dispatchers, config)
  local args = {
    "clangd",
    "--background-index",
    "--header-insertion=iwyu",
    "--completion-style=detailed",
    "--function-arg-placeholders",
    "--fallback-style=llvm",
    "--query-driver=/usr/bin/*,/usr/lib/ccache/*",
    "-j=4",
  }
  local db = M.dir_for(config and config.root_dir)
  if db then table.insert(args, "--compile-commands-dir=" .. db) end
  return vim.lsp.rpc.start(args, dispatchers, { cwd = config and config.root_dir })
end

return M
