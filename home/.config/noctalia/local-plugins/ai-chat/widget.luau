--!nonstrict
-- Bar widget: a chat icon. Click toggles the AI chat panel.

local M = {}

local function render()
    barWidget.setGlyph(noctalia.getConfig("glyph") or "message-chatbot")
    barWidget.setTooltip("AI chat (Claude / Codex)")
end

function M.onClick()
    noctalia.runAsync((noctalia.getenv("HOME") or "~") .. "/.local/bin/aichat-toggle")
end

function onClick()
    M.onClick()
end

-- `noctalia msg plugin local/ai-chat:chat all click` does the same as a click.
function onIpc(event, payload)
    if event == "click" then
        M.onClick()
    end
end

function onConfigChanged()
    render()
end

render()

return M
