-- Copilot is installed but DEACTIVATED by default: no inline suggestions appear.
-- Claude (avante) is the primary coding agent instead.
--
-- To enable Copilot inline suggestions on demand:
--   1. First time only, authenticate:  :Copilot auth
--   2. Toggle suggestions with  <leader>cp  (turns auto-suggestions on/off)
--   When on:  <M-l> accept · <M-]> next · <M-[> prev
return {
  "zbirenbaum/copilot.lua",
  opts = {
    suggestion = {
      enabled = true,
      auto_trigger = false, -- OFF by default — nothing shows until you toggle it on
      keymap = { accept = "<M-l>", next = "<M-]>", prev = "<M-[>" },
    },
    panel = { enabled = false },
  },
  keys = {
    {
      "<leader>cp",
      function()
        require("copilot.suggestion").toggle_auto_trigger()
        local on = vim.b.copilot_suggestion_auto_trigger
        vim.notify("Copilot suggestions " .. (on and "ENABLED" or "disabled"))
      end,
      desc = "Toggle Copilot suggestions",
    },
  },
}
