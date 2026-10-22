-- Look and feel configuration

hl.config({
    general = {
        gaps_in = 5,
        gaps_out = 14,
        border_size = 2,
        extend_border_grab_area = 10,
        resize_on_border = true,
        col = {
            active_border = {
                colors = { "rgba(f4b8a0ee)", "rgba(e6a0c4ee)", "rgba(c9a8f0ee)" },
                angle = 45,
            },
            inactive_border = "rgba(4a3d3d99)",
        },
    },
    group = {
        col = {
            border_active = CACHYLBLUE,
            border_inactive = CACHYGRAY,
            border_locked_active = CACHYDBLUE,
            border_locked_inactive = CACHYGRAY,
        },
        groupbar = {
            col = {
                active = CACHYLGREEN,
                inactive = CACHYGRAY,
                locked_active = CACHYDBLUE,
                locked_inactive = CACHYGRAY,
            },
        },
    },
    decoration = {
        dim_special = 0.3,
        rounding = 16,
        active_opacity = 0.96,
        inactive_opacity = 0.90,
        fullscreen_opacity = 1,
        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            noise = 0.02,
            contrast = 0.95,
            brightness = 1.0,
            vibrancy = 0.25,
            special = true,
        },
        shadow = {
            enabled = true,
            range = 24,
            render_power = 3,
            color = "rgba(1a1010aa)",
        },
    },
})
