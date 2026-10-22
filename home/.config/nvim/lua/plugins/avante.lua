-- Avante talks to the Anthropic API directly (pay-per-token, needs
-- ANTHROPIC_API_KEY) and CANNOT use a Claude subscription. It is therefore
-- DISABLED — the subscription-based agent lives in lua/plugins/claudecode.lua.
--
-- To switch back to avante on the API: set `enabled = true` below and export
-- ANTHROPIC_API_KEY in your shell.
return {
  "yetone/avante.nvim",
  enabled = false,
  opts = {
    provider = "claude",
    claude = {
      model = "claude-sonnet-4-6",
    },
  },
}
