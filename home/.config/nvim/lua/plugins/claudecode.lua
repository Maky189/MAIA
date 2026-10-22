-- Claude as the in-editor coding agent, powered by the Claude Code CLI.
-- This uses your Claude SUBSCRIPTION (Pro/Max) — not the pay-per-token API —
-- because it drives the `claude` CLI, which authenticates to your account.
--
-- One-time setup:
--   1. Make sure the Claude Code CLI is installed and on PATH (`claude`).
--   2. Run `claude` in a terminal, then `/login` and pick your Claude account.
--
-- Then inside nvim:  <leader>ac  toggles the Claude sidebar.
return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {
    -- VS Code-like sidebar: Claude lives in a right-hand split, diffs open as native nvim diffs.
    terminal = {
      split_side = "right",
      split_width_percentage = 0.22,
      provider = "snacks",
      auto_close = true,
    },
    diff_opts = {
      layout = "vertical",
      open_in_new_tab = false,
      keep_terminal_focus = false,
    },
    -- Resolve the `claude` binary robustly: prefer PATH, fall back to the
    -- usual local install locations (avoids "claude not found" if PATH is thin).
    terminal_cmd = (function()
      local p = vim.fn.exepath("claude")
      if p ~= "" then
        return p
      end
      -- Per-OS fallback locations when `claude` isn't on PATH.
      local candidates
      if vim.fn.has("win32") == 1 then
        candidates = {
          "~/.local/bin/claude.exe",
          "~/AppData/Roaming/npm/claude.cmd", -- npm global install
          "~/AppData/Local/Programs/claude/claude.exe",
        }
      else
        candidates = {
          "~/.local/bin/claude",
          "~/.npm-global/bin/claude", -- npm global install
        }
      end
      for _, c in ipairs(candidates) do
        local full = vim.fn.expand(c)
        if vim.fn.executable(full) == 1 then
          return full
        end
      end
      -- Last resort: bare name, let the shell resolve it.
      return "claude"
    end)(),
  },
  keys = {
    { "<leader>a", nil, desc = "AI (Claude / Codex)" },
    { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Toggle Claude" },
    { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
    { "<leader>ar", "<cmd>ClaudeCode --resume<cr>", desc = "Resume Claude" },
    { "<leader>aC", "<cmd>ClaudeCode --continue<cr>", desc = "Continue Claude" },
    { "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", desc = "Select Claude model" },
    { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "Add current buffer" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send selection to Claude" },
    {
      "<leader>as",
      "<cmd>ClaudeCodeTreeAdd<cr>",
      desc = "Add file to Claude",
      ft = { "NvimTree", "neo-tree", "oil", "minifiles" },
    },
    -- Diff review (when Claude proposes an edit)
    { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Accept Claude diff" },
    { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Deny Claude diff" },
  },
}
