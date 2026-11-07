-- Všechny klávesové a myší zkratky prostředí. Okna ovládá klávesa Super. Command (levý Alt) posílá přes keyd Ctrl,
-- Super jen u Q, mezerníku, M a H, v terminálu i u jeho zkratek (system/keyd/desk-cmd, keyd-mode.sh).
local config = require("config")
local geometry = require("geometry")
local arrow_pressed = require("snap").arrow_pressed

local bar_height = geometry.bar_height
local is_visible = geometry.is_visible
local minimized_workspace = config.minimized_workspace

for _, side in ipairs({ "left", "right", "up", "down" }) do
    hl.bind("SUPER + " .. side, function() arrow_pressed(side) end)
end

-- Ctrl + Shift + T: v terminálu nová záložka, jinde zvedne běžící terminál, a když žádný neběží, otevře nový
local terminal_class = config.classes.terminal

local function terminal_shortcut()
    local active = hl.get_active_window()
    if active and active.class == terminal_class then
        hl.dispatch(hl.dsp.send_shortcut({ mods = "CTRL SHIFT", key = "T", window = active }))
        return
    end

    local terminal
    for _, win in ipairs(hl.get_windows()) do
        if win.class == terminal_class then
            terminal = win
            break
        end
    end

    if not terminal then
        hl.exec_cmd("ghostty --gtk-single-instance=true")
        return
    end

    local minimized = terminal.workspace and terminal.workspace.name == minimized_workspace
    restore_window(terminal.address, minimized and hl.get_active_monitor().active_workspace.id or nil)
end

hl.bind("CTRL + SHIFT + T", function() terminal_shortcut() end)
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", function() toggle_maximize() end)
hl.bind("SUPER + SHIFT + F", hl.dsp.exec_cmd(config.shell_ipc("files open")))

-- Command + ťuknutí na Shift přepne rozložení klávesnice: keyd posílá F22 (kód 200), viz system/keyd/desk-cmd
for _, keys in ipairs({ "code:200", "CTRL + code:200" }) do
    hl.bind(keys, hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))
end

-- Alt + Tab na pravém Altu: karusel oken na monitoru s fokusem, po puštění Alt se vybrané okno zvedne.
-- Zpět jde šipkou.
hl.bind("ALT + TAB", hl.dsp.global("caelestia:windowSwitcherNext"), { repeating = true })
hl.bind("ALT + Alt_L", hl.dsp.global("caelestia:windowSwitcherCommit"), { release = true, non_consuming = true })
hl.bind("ALT + Alt_R", hl.dsp.global("caelestia:windowSwitcherCommit"), { release = true, non_consuming = true })

-- Cmd + Tab jako Alt + Tab: keyd posílá F23 (kód 201) při drženém Ctrl, puštěním Command se okno vybere (system/keyd/desk-cmd)
hl.bind("CTRL + code:201", hl.dsp.global("caelestia:windowSwitcherNext"), { repeating = true })
hl.bind("CTRL + Control_L", hl.dsp.global("caelestia:windowSwitcherCommit"), { release = true, non_consuming = true })
hl.bind("CTRL + Control_R", hl.dsp.global("caelestia:windowSwitcherCommit"), { release = true, non_consuming = true })

-- Ťuknutí na Super otevře menu aplikací: keyd při ťuknutí posílá F24 (kód 202), viz keyd-mode.sh
hl.bind("code:202", hl.dsp.exec_cmd(config.shell_ipc("launcher toggle")))

-- Systémové zkratky jako na Macu: Cmd + mezerník otevře nabídku, Cmd + M a Cmd + H schovají okno
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(config.shell_ipc("launcher toggle")))
-- Přehled oken jako Mission Control (panel/Overview.qml), historie schránky a emoji jako na Macu (Ctrl + Cmd + mezerník)
hl.bind("SUPER + TAB", hl.dsp.exec_cmd(config.shell_ipc("overview toggle")))
hl.bind("SUPER + V", hl.dsp.exec_cmd("caelestia clipboard"))
hl.bind("CTRL + SUPER + SPACE", hl.dsp.exec_cmd("caelestia emoji --picker"))
hl.bind("SUPER + M", function() minimize_active() end)
hl.bind("SUPER + H", function() minimize_active() end)

-- Pravý klik na titulkovou lištu otevře nabídku okna (připnutí navrch a ovládání, panel/WindowMenu.qml).
-- Klik se zároveň předá dál, takže pravý klik uvnitř okna dál patří aplikaci.
local function in_rect(pos, x, y, w, h)
    return pos.x >= x and pos.x < x + w and pos.y >= y and pos.y < y + h
end

local function on_bar(pos, win)
    return in_rect(pos, win.at.x, win.at.y - bar_height, win.size.x, bar_height)
end

local function on_body(pos, win)
    return in_rect(pos, win.at.x, win.at.y, win.size.x, win.size.y)
end


-- Pořadí oken pod kurzorem Lua nezná: lišta platí jen tehdy, když ji nezakrývá tělo jiného okna
local function bar_window_at(pos)
    local active = hl.get_active_window()
    if active and is_visible(active) then
        if on_bar(pos, active) then return active end
        if on_body(pos, active) then return nil end
    end

    local hit
    for _, win in ipairs(hl.get_windows()) do
        if is_visible(win) then
            if on_body(pos, win) then return nil end
            if on_bar(pos, win) then hit = win end
        end
    end
    return hit
end

hl.bind("mouse:273", function()
    local pos = hl.get_cursor_pos()
    local win = pos and bar_window_at(pos)
    if win then
        -- Tvar adresy sjednocuje HyprWindows.address v shellu
        hl.exec_cmd(string.format(config.shell_ipc("windowmenu open %s %d %d %s"), win.address, math.floor(pos.x), math.floor(pos.y), tostring(win.pinned)))
    end
end, { non_consuming = true })

-- Screenshot: stejné klávesy jako v Plasmě, stejná akce jako tlačítko v panelu; Cmd + Shift + 4 jako na Macu
-- (kód klávesy 4 kvůli české klávesnici, Super je varianta z režimu terminálu v keyd-mode.sh)
for _, keys in ipairs({ "Print", "SHIFT + Print", "CTRL + SHIFT + code:13", "SUPER + SHIFT + code:13" }) do
    hl.bind(keys, hl.dsp.exec_cmd(config.shell_ipc("picker openFreezeClip")))
end

-- Multimediální klávesy: fungují i na zamčené obrazovce, hlasitost a jas se při držení opakují
local volume_step = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ "
local media_keys = {
    { "XF86AudioRaiseVolume", hl.dsp.exec_cmd(volume_step .. "5%+"), true },
    { "XF86AudioLowerVolume", hl.dsp.exec_cmd(volume_step .. "5%-"), true },
    { "XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") },
    { "XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle") },
    { "XF86MonBrightnessUp", hl.dsp.global("caelestia:brightnessUp"), true },
    { "XF86MonBrightnessDown", hl.dsp.global("caelestia:brightnessDown"), true },
    { "XF86AudioPlay", hl.dsp.global("caelestia:mediaToggle") },
    { "XF86AudioPause", hl.dsp.global("caelestia:mediaToggle") },
    { "XF86AudioNext", hl.dsp.global("caelestia:mediaNext") },
    { "XF86AudioPrev", hl.dsp.global("caelestia:mediaPrev") },
    { "XF86AudioStop", hl.dsp.global("caelestia:mediaStop") },
}

for _, key in ipairs(media_keys) do
    hl.bind(key[1], key[2], { locked = true, repeating = key[3] or false })
end

-- Přesun okna: tažení za titulkovou lištu nebo Super + klik kamkoli do okna (změna velikosti jde tažením za okraj)
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true })
