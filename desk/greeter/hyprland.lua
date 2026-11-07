-- Hyprland jen pro přihlašovací obrazovku; shell je jediné, co na něm běží
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("XCURSOR_SIZE", "24")

hl.config({
    animations = { enabled = false },
    input = {
        kb_layout = "us",
        repeat_delay = 250,
        repeat_rate = 35,
        numlock_by_default = true,
    },
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        background_color = "rgb(0c0e12)",
    },
})

hl.on("hyprland.start", function()
    hl.exec_cmd("/usr/share/desk-greeter/run-shell.sh")
end)
