-- TerraFora engine: build and run from the editor, like F5 / F7 in Visual Studio.
-- Everything goes through <engine>/tools/terrafora.sh, which builds linux/Debug, runs the
-- editor fresh (no project) with prime-run (NVIDIA), windowed and maximized over the
-- Hyprland workspace. Play opens the game folder nvim was started in, else active_game.txt.
local M = {}

local FALLBACK_ROOT = vim.fn.expand("~/Projects/TerraFora-Engine")
local term = { buf = nil, win = nil, job = nil }

local function engine_root()
  for dir in vim.fs.parents(vim.fn.getcwd() .. "/x") do
    if vim.uv.fs_stat(dir .. "/tools/terrafora.sh") then
      return dir
    end
  end
  if vim.uv.fs_stat(FALLBACK_ROOT .. "/tools/terrafora.sh") then
    return FALLBACK_ROOT
  end
end

-- Compiler errors from the last run go to the quickfix list (the location prefix is on
-- the first line even when a long message wraps in the terminal).
local function fill_quickfix(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  vim.fn.setqflist({}, " ", {
    title = "TerraFora build",
    lines = lines,
    efm = "%f:%l:%c: %trror: %m,%f:%l:%c: fatal %trror: %m,%f:%l: undefined reference to %m",
  })
  local items = vim.tbl_filter(function(i) return i.valid == 1 end, vim.fn.getqflist())
  vim.fn.setqflist(items, "r")
  if #items > 0 then
    vim.cmd("copen")
  end
end

local function hide_term()
  if term.win and vim.api.nvim_win_is_valid(term.win) and #vim.api.nvim_tabpage_list_wins(0) > 1 then
    vim.api.nvim_win_close(term.win, false)
  end
  term.win = nil
end

local function show_term()
  if term.win and vim.api.nvim_win_is_valid(term.win) then
    return
  end
  local back = vim.api.nvim_get_current_win()
  vim.cmd("botright 14split")
  term.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term.win, term.buf)
  vim.api.nvim_set_current_win(back)
end

local function close_term()
  if term.job then
    pcall(vim.fn.jobstop, term.job)
  end
  if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
    vim.api.nvim_buf_delete(term.buf, { force = true })
  end
  term = { buf = nil, win = nil, job = nil }
end

function M.run(cmd, env)
  local root = engine_root()
  if not root then
    vim.notify("TerraFora engine not found", vim.log.levels.ERROR)
    return
  end
  vim.cmd("silent! wall")
  close_term()
  local back = vim.api.nvim_get_current_win()
  vim.cmd("botright 14split")
  term.win = vim.api.nvim_get_current_win()
  term.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(term.win, term.buf)
  local args = vim.list_extend({ root .. "/tools/terrafora.sh" }, cmd)
  -- The split hides itself once the build has passed (run/play keep going in it, and
  -- <leader>mt brings it back) and comes back on its own when anything fails.
  term.job = vim.fn.jobstart(args, {
    term = true,
    cwd = vim.fn.getcwd(),
    env = env,
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line:find("terrafora: build succeeded", 1, true) then
          vim.schedule(hide_term)
          return
        end
      end
    end,
    on_exit = function(_, code)
      term.job = nil
      vim.schedule(function()
        if code == 0 then
          hide_term()
        elseif term.buf and vim.api.nvim_buf_is_valid(term.buf) then
          show_term()
          fill_quickfix(term.buf)
          vim.notify("TerraFora: " .. cmd[1] .. " exited with " .. code, vim.log.levels.WARN)
        end
      end)
    end,
  })
  vim.api.nvim_set_current_win(back)
end

function M.toggle_term()
  if term.win and vim.api.nvim_win_is_valid(term.win) then
    hide_term()
  elseif term.buf and vim.api.nvim_buf_is_valid(term.buf) then
    show_term()
  end
end

function M.open_log()
  local root = engine_root()
  if root then
    vim.cmd("edit " .. vim.fn.fnameescape(root .. "/linux/Debug/terrafora.log"))
    vim.cmd("normal! G")
  end
end

local map = vim.keymap.set
map("n", "<F5>", function() M.run({ "run" }) end, { desc = "TerraFora: build + run editor" })
map("n", "<F7>", function() M.run({ "build" }) end, { desc = "TerraFora: build" })
map("n", "<leader>mr", function() M.run({ "run" }) end, { desc = "Build + run editor" })
map("n", "<leader>mp", function() M.run({ "play" }) end, { desc = "Build + play game" })
map("n", "<leader>mw", function() M.run({ "run" }, { TERRAFORA_PLACE = "workspace" }) end,
  { desc = "Build + run on its own workspace" })
map("n", "<leader>mb", function() M.run({ "build" }) end, { desc = "Build" })
map("n", "<leader>mk", function() vim.fn.system({ "pkill", "-x", "TerraFora" }) end, { desc = "Kill engine" })
map("n", "<leader>mt", M.toggle_term, { desc = "Toggle build/run terminal" })
map("n", "<leader>ml", M.open_log, { desc = "Open terrafora.log" })

local ok, wk = pcall(require, "which-key")
if ok then
  wk.add({ { "<leader>m", group = "TerraFora" } })
end

return M
