-- Vlastní prostředí "desk". Nezávislé na výchozí konfiguraci Caelestie, jen barvy bere z jejího schématu.
local home = os.getenv("HOME")
package.path = package.path .. ";" .. home .. "/.config/desk/?.lua;" .. home .. "/.config/hypr/?.lua"

local scheme = require("scheme.current")
local cursor_theme = "breeze_cursors"
local cursor_size = 24

-- Monitory
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "0x0", scale = 1 })
hl.monitor({ output = "DP-1", mode = "2560x1440@165", position = "2560x0", scale = 1 })

hl.workspace_rule({ workspace = "1", monitor = "HDMI-A-1", default = true, persistent = true })
hl.workspace_rule({ workspace = "2", monitor = "DP-1", default = true, persistent = true })

-- Prostředí aplikací
hl.env("QT_QPA_PLATFORMTHEME", "qtengine")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("XCURSOR_THEME", cursor_theme)
hl.env("XCURSOR_SIZE", tostring(cursor_size))
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("SDL_VIDEODRIVER", "wayland,x11,windows")
hl.env("CLUTTER_BACKEND", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

-- Vzhled a chování oken
hl.config({
    general = {
        layout = "dwindle",
        gaps_in = 5,
        gaps_out = 5,
        border_size = 1,
        resize_on_border = true,
        col = {
            active_border = "rgba(" .. scheme.primary .. "e6)",
            inactive_border = "rgba(" .. scheme.onSurfaceVariant .. "11)",
        },
    },
    decoration = {
        rounding = 15,
        rounding_power = 2,
        blur = { enabled = true, size = 8, passes = 2, ignore_opacity = true, new_optimizations = true },
        shadow = { enabled = true, range = 15, render_power = 4, color = "rgba(" .. scheme.inversePrimary .. "10)" },
    },
    input = {
        kb_layout = "us,cz",
        kb_variant = ",winkeys-qwerty", -- česká QWERTY s rozmístěním znaků jako na Windows
        kb_options = "grp:alt_shift_toggle", -- Alt + Shift přepíná rozložení
        repeat_delay = 250,
        repeat_rate = 35,
        follow_mouse = 2, -- fokus až po kliknutí, jako v Plasmě
    },
    cursor = {
        no_warps = true, -- kurzor zůstává na místě i při změně fokusu
    },
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = 0,
        focus_on_activate = true,
        allow_session_lock_restore = true,
        session_lock_xray = true,
        middle_click_paste = false,
        background_color = "rgb(" .. scheme.surfaceContainer .. ")",
    },
})

-- Průhledný shell s rozostřením; okna aplikací průhledná nejsou
hl.layer_rule({ match = { namespace = "caelestia-desk-(panel|overlay)" }, blur = true, ignore_alpha = 0.3 })

-- Všechna okna plovoucí, jako v Plasmě
hl.window_rule({ match = { class = ".*" }, float = true })
hl.window_rule({ match = { class = "^jetbrains-.*$" }, opaque = true })
hl.window_rule({ match = { class = "^jetbrains-toolbox$" }, ["hyprbars:no_bar"] = true })
hl.window_rule({ match = { class = "^jetbrains-.*$", title = "^splash$" }, ["hyprbars:no_bar"] = true }) -- úvodní obrazovka IDE není normální okno

-- Titulkové lišty, zkratky a ovládání oken
require("bars")
require("windows")
require("window-memory").start()
require("keyboard")

-- Autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor " .. cursor_theme .. " " .. cursor_size)
    hl.exec_cmd(home .. "/.config/desk/recolor-icons.sh") -- schéma se mohlo změnit v jiném prostředí
    hl.exec_cmd("qs -c desk -n -d")

    -- Při zkoušení v okně uvnitř Plasmy (DESK_NESTED=1) se systémové služby nespouští
    if os.getenv("DESK_NESTED") then return end

    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme " .. cursor_theme)
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size " .. cursor_size)
    -- Ovládání oken je jen v liště vlevo: aplikace si vlastní tlačítka nekreslí (GTK, IntelliJ)
    hl.exec_cmd("gsettings set org.gnome.desktop.wm.preferences button-layout :")
    hl.exec_cmd("mpris-proxy")
    hl.exec_cmd(home .. "/.config/desk/nightshift.sh")

    -- Aplikace po přihlášení, nastavují se v Nexusu
    hl.exec_cmd(home .. "/.config/desk/autostart.sh")

    hl.exec_cmd("xrandr --output HDMI-A-1 --primary")
    hl.dispatch(hl.dsp.focus({ monitor = "HDMI-A-1" }))
end)
