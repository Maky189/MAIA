-- OpenAI Codex CLI as a second in-editor agent, next to Claude (<leader>a group).
-- Codex runs in a right-hand sidebar terminal (same layout as Claude), and you can
-- push the current file or a visual selection into it like VS Code's "Add to chat".
--
-- One-time setup: run `codex` in a terminal and sign in (ChatGPT account or API key).
--
--   <leader>ax  toggle Codex sidebar          <leader>aX  resume last Codex session
--   <leader>ab  (Claude) add file to Claude   <leader>aB  add current file to Codex
--   <leader>as  (Claude) send selection       <leader>aS  send selection to Codex
--   <C-,>       toggle Codex from anywhere (incl. terminal mode)
local function codex_bin()
  local p = vim.fn.exepath("codex")
  return p ~= "" and p or "codex"
end

local function root()
  local ok, r = pcall(function()
    return LazyVim.root()
  end)
  return ok and r or vim.uv.cwd()
end

local function term_opts()
  return {
    cwd = root(),
    win = {
      position = "right",
      width = 0.22,
      border = "rounded",
      title = "  Codex ",
      title_pos = "center",
      wo = { winbar = "", winhighlight = "NormalFloat:Normal" },
    },
  }
end

local function cmd(args)
  local c = { codex_bin() }
  for _, a in ipairs(args or {}) do
    table.insert(c, a)
  end
  return c
end

local function toggle(args)
  return Snacks.terminal.toggle(cmd(args), term_opts())
end

-- Sends text into the running Codex terminal (opening it first if needed) as a
-- bracketed paste so multi-line snippets are not submitted line by line.
local function send(text)
  local function paste(win)
    local buf = win and win.buf
    local job = buf and vim.b[buf].terminal_job_id
    if not job then
      return vim.notify("Codex terminal is not ready", vim.log.levels.WARN)
    end
    vim.fn.chansend(job, "\27[200~" .. text .. "\27[201~ ")
  end
  local existing = Snacks.terminal.get(cmd(), vim.tbl_extend("force", term_opts(), { create = false }))
  if existing then
    existing:show()
    return paste(existing)
  end
  local win = toggle()
  vim.defer_fn(function()
    paste(win)
  end, 1200)
end

local function rel(path)
  return vim.fn.fnamemodify(path, ":.")
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>ax", function() toggle() end, desc = "Toggle Codex" },
      { "<leader>aX", function() toggle({ "resume" }) end, desc = "Resume Codex" },
      {
        "<leader>aB",
        function()
          local f = vim.api.nvim_buf_get_name(0)
          if f == "" then
            return vim.notify("No file in this buffer", vim.log.levels.WARN)
          end
          send("@" .. rel(f))
        end,
        desc = "Add file to Codex",
      },
      {
        "<leader>aS",
        function()
          -- Leave visual mode first so '< and '> are set.
          vim.cmd("normal! \27")
          local s, e = vim.fn.line("'<"), vim.fn.line("'>")
          local lines = vim.api.nvim_buf_get_lines(0, s - 1, e, false)
          local ft = vim.bo.filetype
          send(("%s:%d-%d\n```%s\n%s\n```\n"):format(rel(vim.api.nvim_buf_get_name(0)), s, e, ft, table.concat(lines, "\n")))
        end,
        mode = "v",
        desc = "Send selection to Codex",
      },
      { "<C-,>", function() toggle() end, mode = { "n", "t", "i" }, desc = "Toggle Codex" },
    },
  },
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>a", group = "ai", icon = { icon = "󰧑 ", color = "purple" } },
      },
    },
  },
}
