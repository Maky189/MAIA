-- Remember the mode of the last closed window for each application class.
-- Plain data (hex-encoded class + mode), never executable Lua.
local state_dir = os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")
local state_file = state_dir .. "/hypr-window-modes"
local modes = {}

local function encode(value)
    return (value:gsub(".", function(c) return string.format("%02x", c:byte()) end))
end

local file = io.open(state_file, "r")
if file then
    for line in file:lines() do
        local key, mode = line:match("^([0-9a-f]+) ([01])$")
        if key then modes[key] = mode == "1" end
    end
    file:close()
end

local function app_key(window)
    local class = window.initial_class
    if not class or class == "" then class = window.class end
    if not class or class == "" then return nil end
    return encode(class)
end

local function save(window)
    local key = app_key(window)
    if not key then return end
    local mode = window.floating
    if modes[key] == mode then return end
    modes[key] = mode
    local output, err = io.open(state_file .. ".tmp", "w")
    if not output then error("Cannot save window modes: " .. tostring(err)) end
    local keys = {}
    for saved_key in pairs(modes) do keys[#keys + 1] = saved_key end
    table.sort(keys)
    for _, saved_key in ipairs(keys) do
        assert(output:write(saved_key, modes[saved_key] and " 1\n" or " 0\n"))
    end
    assert(output:close())
    assert(os.rename(state_file .. ".tmp", state_file))
end

hl.on("window.close", save)

-- Apply after mapping and initial window rules, and target this exact window.
-- Keep timer objects alive until their callbacks finish.
local pending = {}
hl.on("window.open", function(window)
    local address = window.address
    pending[address] = hl.timer(function()
        pending[address] = nil
        local current = hl.get_window(address)
        if not current or not current.mapped then return end
        local key = app_key(current)
        local mode = key and modes[key]
        if mode ~= nil and current.floating ~= mode then
            hl.dispatch(hl.dsp.window.float({ window = current, action = "toggle" }))
        end
    end, { timeout = 50, type = "oneshot" })
end)
