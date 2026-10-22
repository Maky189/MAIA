-- Diagnostics: turn off all the visual noise.
--   * no red/squiggly underlines
--   * no inline virtual text
--   * no sign-column markers
-- Syntax highlighting is done by treesitter and is left completely untouched,
-- so an undefined function or a missing import is still colored normally —
-- only an actual syntax error loses its highlighting (treesitter's job).
-- LSP itself stays on, so go-to-definition / hover / rename still work.
return {
  "neovim/nvim-lspconfig",
  opts = {
    diagnostics = {
      underline = false,
      virtual_text = false,
      signs = false,
      update_in_insert = false,
    },
  },
}
