-- Input configuration

hl.config({
    input = {
        -- Same feel as KDE Plasma / Linux Mint: libinput's adaptive curve (slow = precise, fast flick = far).
        accel_profile = "adaptive",
        sensitivity = 0.1,          -- -1.0 .. 1.0, 0 = stock; raise for faster, lower for slower
        natural_scroll = false,     -- mouse wheel: normal direction (touchpad below stays natural)
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
            clickfinger_behavior = true,   -- 2-finger click = right click
            scroll_factor = 1.0,
        },
    },
    -- Uncomment the section below to enable software cursors; this can help with cursor display or behavior issues
    -- cursor = {
    --     no_hardware_cursors = 1,
    -- },
})

hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down",       action = "close" })
hl.gesture({ fingers = 3, direction = "up",         action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "left",       action = "float" })
