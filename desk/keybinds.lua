-- Všechny klávesové a myší zkratky prostředí. Klávesa Command posílá přes keyd Super jen u šipek, F a Q,
-- v terminálu i u jeho zkratek, jinde Ctrl (keyboard.lua, keyd-mode.sh).
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
hl.bind("ALT + SHIFT + F", hl.dsp.exec_cmd(config.shell_ipc("files open")))

-- Alt + Tab: karusel oken na monitoru s fokusem, po puštění Alt se vybrané okno zvedne.
-- Shift + Alt + Tab tu záměrně není, Alt + Shift přepíná rozložení klávesnice; zpět jde šipkou.
hl.bind("ALT + TAB", hl.dsp.global("caelestia:windowSwitcherNext"), { repeating = true })
hl.bind("ALT + Alt_L", hl.dsp.global("caelestia:windowSwitcherCommit"), { release = true, non_consuming = true })
hl.bind("ALT + Alt_R", hl.dsp.global("caelestia:windowSwitcherCommit"), { release = true, non_consuming = true })

-- Ťuknutí na Command otevře menu aplikací: keyd při ťuknutí posílá F24 (kód 202), viz keyd-mode.sh
hl.bind("code:202", hl.dsp.exec_cmd(config.shell_ipc("launcher toggle")))

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
        local address = win.address:gsub("^0x", "")
        hl.exec_cmd(string.format(config.shell_ipc("windowmenu open 0x%s %d %d %s"), address, math.floor(pos.x), math.floor(pos.y), tostring(win.pinned)))
    end
end, { non_consuming = true })

-- Screenshot: stejné klávesy jako v Plasmě, stejná akce jako tlačítko v panelu
for _, keys in ipairs({ "Print", "SHIFT + Print" }) do
    hl.bind(keys, hl.dsp.exec_cmd(config.shell_ipc("picker openFreezeClip")))
end

-- Přesun okna: tažení za titulkovou lištu nebo Alt + klik kamkoli do okna (změna velikosti jde tažením za okraj)
hl.bind("ALT + mouse:272", hl.dsp.window.drag(), { mouse = true })
