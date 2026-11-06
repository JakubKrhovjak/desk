-- Jediné klávesové zkratky prostředí: Super + šipky, Super + Q, Super + F, Ctrl + Shift + T, Print, Shift + Print, Alt + Shift + F, ťuknutí na Command. Klávesa Command posílá přes keyd Super jen u šipek, F a Q, jinak Ctrl (keyboard.lua).

local snap_gap = 10 -- mezera mezi okny
local outer_gap = 5 -- mezera mezi okny a okrajem plochy
local bar_height = require("bars").height

local function snap_rect(side, x, y, w, h)
    local half_w = math.floor((w - snap_gap) / 2)
    local half_h = math.floor((h - snap_gap) / 2)

    return ({
        left  = { x = x, y = y, w = half_w, h = h },
        right = { x = x + w - half_w, y = y, w = half_w, h = h },
        up    = { x = x, y = y, w = w, h = half_h },
        down  = { x = x, y = y + h - half_h, w = w, h = half_h },
    })[side]
end

-- Pracovní plocha monitoru bez panelu a s mezerou kolem
local function monitor_snap_rect(mon, side)
    local res = mon.reserved

    local rect = snap_rect(
        side,
        mon.x + res.left + outer_gap,
        mon.y + res.top + outer_gap,
        math.floor(mon.width / mon.scale - res.left - res.right - 2 * outer_gap),
        math.floor(mon.height / mon.scale - res.top - res.bottom - 2 * outer_gap)
    )

    -- Titulková lišta je nad oknem a počítá se do zabrané plochy
    return { x = rect.x, y = rect.y + bar_height, w = rect.w, h = rect.h - bar_height }
end

local function is_at(win, rect)
    return win.floating
        and math.abs(win.at.x - rect.x) <= 2 and math.abs(win.at.y - rect.y) <= 2
        and math.abs(win.size.x - rect.w) <= 2 and math.abs(win.size.y - rect.h) <= 2
end

local function neighbour_monitor(mon, side)
    local right_edge = mon.x + mon.width / mon.scale

    for _, other in ipairs(hl.get_monitors()) do
        local other_right = other.x + other.width / other.scale
        if (side == "right" and other.x == right_edge) or (side == "left" and other_right == mon.x) then
            return other
        end
    end
end

local function apply_rect(win, x, y, w, h)
    hl.dispatch(hl.dsp.window.resize({ x = w, y = h, relative = false, window = win }))
    hl.dispatch(hl.dsp.window.move({ x = x, y = y, relative = false, window = win }))
end

local snap_opposite = { left = "right", right = "left" }

-- Super + šipka: půlka obrazovky; další stisk stejným směrem přehodí okno na sousední monitor
local function snap_window(side)
    return function()
        local win = hl.get_active_window()
        local mon = win and (win.monitor or hl.get_active_monitor())
        if not win or not mon then return end

        local rect = monitor_snap_rect(mon, side)
        local target = snap_opposite[side] and is_at(win, rect) and neighbour_monitor(mon, side)
        if target then
            hl.dispatch(hl.dsp.window.move({ workspace = target.active_workspace.id, window = win }))
            rect = monitor_snap_rect(target, snap_opposite[side])
        end

        hl.dispatch(hl.dsp.window.float({ action = "on", window = win }))
        apply_rect(win, rect.x, rect.y, rect.w, rect.h)
    end
end

-- Celá pracovní plocha monitoru přesně po panel, bez mezery
local function maximized_rect(mon)
    local res = mon.reserved

    return {
        x = mon.x + res.left,
        y = mon.y + res.top + bar_height,
        w = math.floor(mon.width / mon.scale - res.left - res.right),
        h = math.floor(mon.height / mon.scale - res.top - res.bottom) - bar_height,
    }
end

-- Super + F: maximalizace přesně po panel, bez mezery; další stisk vrátí původní velikost
local unmaximized = {}

function toggle_maximize(target)
    local win = target or hl.get_active_window()
    local mon = win and (win.monitor or hl.get_active_monitor())
    if not win or not mon then return end

    local rect = maximized_rect(mon)

    if is_at(win, rect) then
        local old = unmaximized[win.address]
        unmaximized[win.address] = nil

        if old then
            apply_rect(win, mon.x + old.x, mon.y + old.y, old.w, old.h)
        else
            -- Předchozí velikost neznáme (třeba po reloadu): 70 % plochy uprostřed
            apply_rect(win, rect.x + math.floor(rect.w * 0.15), rect.y + math.floor(rect.h * 0.15), math.floor(rect.w * 0.7), math.floor(rect.h * 0.7))
        end
        return
    end

    unmaximized[win.address] = {
        x = win.at.x - mon.x,
        y = win.at.y - mon.y,
        w = win.size.x,
        h = win.size.y,
    }
    hl.dispatch(hl.dsp.window.float({ action = "on", window = win }))
    apply_rect(win, rect.x, rect.y, rect.w, rect.h)
end

-- Minimalizace = skrytá speciální plocha. Hyprland ji ale ukáže, jakmile na ní něco dostane fokus,
-- a na ukázané ploše by minimalizace nic neschovala, proto ji hned zase skrývá.
local minimized_workspace = "special:minimized"

local function hide_minimized()
    for _, mon in ipairs(hl.get_monitors()) do
        local special = mon.active_special_workspace
        if special and special.name == minimized_workspace then
            mon:set_special_workspace(nil)
        end
    end
end

-- Když po zavření nebo minimalizaci nezbude okno s fokusem, psaní by šlo do prázdna, dokud se někam neklikne.
-- Fokus proto jako v Plasmě dostane naposledy používané viditelné okno.
local function focus_next_window()
    if hl.get_active_window() then return end

    local next_window
    for _, win in ipairs(hl.get_windows()) do
        local mon = win.monitor
        local visible = win.mapped and not win.hidden and mon and win.workspace and mon.active_workspace
            and win.workspace.id == mon.active_workspace.id
        if visible and win.class ~= "jetbrains-toolbox"
            and (not next_window or win.focus_history_id < next_window.focus_history_id) then
            next_window = win
        end
    end

    if next_window then
        hl.dispatch(hl.dsp.focus({ window = next_window }))
    end
end

local function focus_next_soon()
    focus_timer = hl.timer(focus_next_window, { timeout = 80, type = "oneshot" })
end

hl.on("window.close", focus_next_soon)
hl.on("window.active", function(win)
    if not win then focus_next_soon() end
end)

-- Tlačítko minimalizace v titulkové liště; okno vrátí klik v panelu.
-- Shell si okno nejdřív vyfotí kvůli animaci (panel/MinimizeAnimation.qml) a pak zavolá finish_minimize.
-- Když neodpoví, okno se schová samo bez animace.
local minimize_fallback_ms = 800
local pending_minimize = {}
local minimize_timers = {}

function finish_minimize(address)
    if not pending_minimize[address] then return end
    pending_minimize[address] = nil
    minimize_timers[address] = nil

    hl.dispatch(hl.dsp.window.move({ workspace = minimized_workspace, follow = false, window = "address:" .. address }))
    hide_minimized()
    focus_next_soon()
end

function minimize_active()
    local win = hl.get_active_window()
    if not win then return end

    local address = win.address
    pending_minimize[address] = true
    hl.exec_cmd(string.format("qs -c desk ipc call minimize animate %s %d %d %d %d", address, win.at.x, win.at.y, win.size.x, win.size.y))
    minimize_timers[address] = hl.timer(function() finish_minimize(address) end, { timeout = minimize_fallback_ms, type = "oneshot" })
end

-- Obnovení z panelu: shell přehraje animaci a na jejím konci zavolá finish_restore; pojistka vrátí okno i bez animace
local restore_fallback_ms = 900
local pending_restore = {}

function finish_restore(address)
    local workspace = pending_restore[address]
    if not workspace then return end
    pending_restore[address] = nil

    local target = "address:" .. address
    hl.dispatch(hl.dsp.window.move({ workspace = workspace, follow = false, window = target }))
    hl.dispatch(hl.dsp.focus({ window = target }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end

function restore_minimized(address, workspace)
    if pending_restore[address] then return end

    pending_restore[address] = workspace
    hl.exec_cmd("qs -c desk ipc call minimize restore " .. address)
    hl.timer(function() finish_restore(address) end, { timeout = restore_fallback_ms, type = "oneshot" })
end

hl.on("workspace.special_active", hide_minimized)

-- Super + obě šipky naráz: roztažení na celou šířku (doleva + doprava) nebo výšku (nahoru + dolů), druhý rozměr zůstává
local function stretch_window(first, second)
    local win = hl.get_active_window()
    local mon = win and (win.monitor or hl.get_active_monitor())
    if not win or not mon then return end

    local a = monitor_snap_rect(mon, first)
    local b = monitor_snap_rect(mon, second)
    local horizontal = first == "left" or first == "right"
    local x = horizontal and math.min(a.x, b.x) or win.at.x
    local y = horizontal and win.at.y or math.min(a.y, b.y)
    local w = horizontal and math.max(a.x + a.w, b.x + b.w) - x or win.size.x
    local h = horizontal and win.size.y or math.max(a.y + a.h, b.y + b.h) - y

    hl.dispatch(hl.dsp.window.float({ action = "on", window = win }))
    apply_rect(win, x, y, w, h)
end

-- Šipka se provede až po krátké chvíli, aby stisk obou naráz okno nepřichytil ani nepřehodil na druhý monitor
local chord_ms = 90
local chord_partner = { left = "right", right = "left", up = "down", down = "up" }
local chord_pending
local chord_press = 0
local chord_timer

function arrow_pressed(side)
    if chord_pending == chord_partner[side] then
        stretch_window(chord_pending, side)
        chord_pending = nil
        return
    end

    chord_pending = side
    chord_press = chord_press + 1
    local press = chord_press
    chord_timer = hl.timer(function()
        if press == chord_press and chord_pending == side then
            chord_pending = nil
            snap_window(side)()
        end
    end, { timeout = chord_ms, type = "oneshot" })
end

for _, side in ipairs({ "left", "right", "up", "down" }) do
    hl.bind("SUPER + " .. side, function() arrow_pressed(side) end)
end

-- Ctrl + Shift + T: v terminálu nová záložka, jinde zvedne běžící terminál, a když žádný neběží, otevře nový
local terminal_class = "com.mitchellh.ghostty"

function terminal_shortcut()
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

    -- Minimalizovaný terminál se nejdřív vrátí na aktuální plochu
    if terminal.workspace and terminal.workspace.name == "special:minimized" then
        hl.dispatch(hl.dsp.window.move({ workspace = hl.get_active_monitor().active_workspace.id, follow = false, window = terminal }))
    end
    hl.dispatch(hl.dsp.focus({ window = terminal }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end

-- Výchozí místo aplikací při otevření. IntelliJ se pozná až podle titulku s projektem,
-- aby se nemaximalizovaly i jeho dialogy (mají stejnou třídu okna).
local function toolbox_rect(mon, win)
    local res = mon.reserved
    return {
        x = math.floor(mon.x + mon.width / mon.scale - res.right - win.size.x - snap_gap),
        y = mon.y + res.top + snap_gap,
        w = win.size.x,
        h = win.size.y,
    }
end

local home_places = {
    {
        matches = function(win)
            return win.class == "jetbrains-idea" and (win.title:find(" – ", 1, true) or win.title == "Welcome to IntelliJ IDEA")
        end,
        monitor = "HDMI-A-1",
        rect = maximized_rect,
    },
    {
        matches = function(win) return win.class == terminal_class and win.initial_title == "Ghostty" end,
        monitor = "DP-1",
        rect = function(mon) return monitor_snap_rect(mon, "right") end,
    },
    {
        matches = function(win) return win.class == "org.quickshell" and win.title == "Files" end,
        monitor = "DP-1",
        rect = function(mon) return monitor_snap_rect(mon, "left") end,
    },
    {
        -- Toolbox se sám otevírá na y = 0, pod panelem; patří vpravo nahoře pod panel a velikost si drží svou
        matches = function(win) return win.class == "jetbrains-toolbox" end,
        monitor = "HDMI-A-1",
        rect = toolbox_rect,
    },
}

-- Každé okno se umístí jen jednou. Okna otevřená před načtením konfigurace se nepřesouvají.
-- Pravidla platí už při vzniku okna, takže okno neproblikne jinde a nepřeskakuje mezi monitory.
-- place_on_open pak jen doladí přesné rozměry. DP-1 nemá panel, proto stačí počítat s lištou a mezerou.
local half_width = "((monitor_w-" .. (2 * outer_gap + snap_gap) .. ")/2)"
local half_height = "(monitor_h-" .. (2 * outer_gap + bar_height) .. ")"
local half_size = half_width .. " " .. half_height

hl.window_rule({
    match = { class = "^com\\.mitchellh\\.ghostty$", initial_title = "^Ghostty$" },
    monitor = "DP-1",
    size = half_size,
    move = "(monitor_w-" .. outer_gap .. "-" .. half_width .. ") " .. (outer_gap + bar_height),
})
hl.window_rule({
    match = { class = "^org\\.quickshell$", title = "^Files$" },
    monitor = "DP-1",
    size = half_size,
    move = outer_gap .. " " .. (outer_gap + bar_height),
})
hl.window_rule({ match = { class = "^jetbrains-idea$" }, monitor = "HDMI-A-1" })
hl.window_rule({ match = { class = "^jetbrains-toolbox$" }, monitor = "HDMI-A-1" })

local placed = {}
for _, win in ipairs(hl.get_windows()) do
    placed[win.address] = true
end

local function place_on_open(win)
    if placed[win.address] then return end

    -- Zapamatovaná poloha má přednost, výchozí místo platí jen při prvním otevření aplikace
    if require("window-memory").has(win) then
        placed[win.address] = true
        return
    end

    for _, place in ipairs(home_places) do
        if place.matches(win) then
            placed[win.address] = true
            local mon = hl.get_monitor(place.monitor) or win.monitor or hl.get_active_monitor()
            local rect = place.rect(mon, win)
            hl.dispatch(hl.dsp.window.float({ action = "on", window = win }))
            hl.dispatch(hl.dsp.window.move({ workspace = mon.active_workspace.id, window = win }))
            apply_rect(win, rect.x, rect.y, rect.w, rect.h)
            return
        end
    end
end

hl.on("window.open", place_on_open)
hl.on("window.title", place_on_open)
hl.on("window.close", function(win) placed[win.address] = nil end)

-- Toolbox okno nezavírá, jen schovává, takže se při každém zobrazení srovná znovu
hl.on("window.active", function(win)
    if win and win.class == "jetbrains-toolbox" then
        placed[win.address] = nil
        place_on_open(win)
    end
end)

-- Toolbox se chová jako vyskakovací panel: schová se, když na něj myš po otevření nenajede nebo když z něj odjede.
-- Zavřením okna běží Toolbox dál v trayi.
local toolbox_tick_ms = 100
local toolbox_open_grace_ms = 3000
local toolbox_leave_grace_ms = 400
local toolbox_margin = 8

local toolbox_entered = false
local toolbox_outside_ms = 0
local toolbox_timer

local function toolbox_windows()
    local found = {}
    for _, win in ipairs(hl.get_windows()) do
        if win.class == "jetbrains-toolbox" then
            found[#found + 1] = win
        end
    end
    return found
end

local function cursor_over(win, cursor)
    return cursor.x >= win.at.x - toolbox_margin
        and cursor.x <= win.at.x + win.size.x + toolbox_margin
        and cursor.y >= win.at.y - bar_height - toolbox_margin
        and cursor.y <= win.at.y + win.size.y + toolbox_margin
end

local function toolbox_tick()
    local windows = toolbox_windows()
    if #windows == 0 then
        toolbox_timer:set_enabled(false)
        return
    end

    -- Toolbox se po otevření sám posouvá pod panel, hlavní okno se proto drží na svém místě po celou dobu
    local home = hl.get_monitor("HDMI-A-1")
    for _, win in ipairs(windows) do
        if home and win.title == "Toolbox" then
            local rect = toolbox_rect(home, win)
            if math.abs(win.at.x - rect.x) > 2 or math.abs(win.at.y - rect.y) > 2 then
                hl.dispatch(hl.dsp.window.move({ x = rect.x, y = rect.y, relative = false, window = win }))
            end
        end
    end

    local cursor = hl.get_cursor_pos()
    if not cursor then return end

    for _, win in ipairs(windows) do
        if cursor_over(win, cursor) then
            toolbox_entered = true
            toolbox_outside_ms = 0
            return
        end
    end

    toolbox_outside_ms = toolbox_outside_ms + toolbox_tick_ms
    if toolbox_outside_ms >= (toolbox_entered and toolbox_leave_grace_ms or toolbox_open_grace_ms) then
        for _, win in ipairs(windows) do
            hl.dispatch(hl.dsp.window.close({ window = win }))
        end
    end
end

toolbox_timer = hl.timer(toolbox_tick, { timeout = toolbox_tick_ms, type = "repeat" })
toolbox_timer:set_enabled(false)

local function watch_toolbox(win)
    if win and win.class == "jetbrains-toolbox" and not toolbox_timer:is_enabled() then
        toolbox_entered = false
        toolbox_outside_ms = 0
        toolbox_timer:set_enabled(true)
    end
end

hl.on("window.open", watch_toolbox)
hl.on("window.active", watch_toolbox)

hl.bind("CTRL + SHIFT + T", function() terminal_shortcut() end)
hl.bind("SUPER + Q", hl.dsp.window.close())
hl.bind("SUPER + F", function() toggle_maximize() end)
hl.bind("ALT + SHIFT + F", hl.dsp.exec_cmd("qs -c desk ipc call files open"))

-- Alt + Tab: karusel oken na monitoru s fokusem, po puštění Alt se vybrané okno zvedne.
-- Shift + Alt + Tab tu záměrně není, Alt + Shift přepíná rozložení klávesnice; zpět jde šipkou.
hl.bind("ALT + TAB", hl.dsp.global("caelestia:windowSwitcherNext"), { repeating = true })
hl.bind("ALT + Alt_L", hl.dsp.global("caelestia:windowSwitcherCommit"), { release = true, non_consuming = true })
hl.bind("ALT + Alt_R", hl.dsp.global("caelestia:windowSwitcherCommit"), { release = true, non_consuming = true })

-- Ťuknutí na Command otevře menu aplikací: keyd při ťuknutí posílá F24 (kód 202), viz keyd-mode.sh
hl.bind("code:202", hl.dsp.exec_cmd("qs -c desk ipc call launcher toggle"))

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

local function is_visible(win)
    local mon = win.monitor
    return win.mapped and not win.hidden and win.workspace and mon
        and (win.pinned or (mon.active_workspace and win.workspace.id == mon.active_workspace.id))
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
        hl.exec_cmd(string.format("qs -c desk ipc call windowmenu open 0x%s %d %d %s", address, pos.x, pos.y, tostring(win.pinned)))
    end
end, { non_consuming = true })

-- Screenshot: stejné klávesy jako v Plasmě, stejná akce jako tlačítko v panelu
for _, keys in ipairs({ "Print", "SHIFT + Print" }) do
    hl.bind(keys, hl.dsp.exec_cmd("qs -c desk ipc call picker openFreezeClip"))
end

-- Přesun okna: tažení za titulkovou lištu nebo Alt + klik kamkoli do okna (změna velikosti jde tažením za okraj)
hl.bind("ALT + mouse:272", hl.dsp.window.drag(), { mouse = true })

-- Okno s fokusem jde dopředu jako v Plasmě. V obsluze události ještě není nastavené jako aktivní, proto až po chvilce.
hl.on("window.active", function(win)
    if win and win.floating then
        raise_timer = hl.timer(function() hl.dispatch(hl.dsp.window.bring_to_top()) end, { timeout = 10, type = "oneshot" })
    end
end)

-- Titulková lišta nesmí zajet pod panel, jinak by za ni okno nešlo chytit.
-- Událost pro konec tažení Hyprland nemá, proto se poloha kontroluje průběžně.
local function keep_bars_reachable()
    for _, win in ipairs(hl.get_windows()) do
        local mon = win.monitor
        local on_special = win.workspace and win.workspace.name:find("special", 1, true)
        local fullscreen = win.fullscreen and win.fullscreen ~= 0
        if mon and win.floating and not win.hidden and not on_special and not fullscreen
            and win.title ~= "" and win.class ~= "jetbrains-toolbox" then
            local top = mon.y + mon.reserved.top + bar_height
            if win.at.y < top then
                hl.dispatch(hl.dsp.window.move({ x = win.at.x, y = top, relative = false, window = win }))
            end
        end
    end
end

bars_timer = hl.timer(keep_bars_reachable, { timeout = 300, type = "repeat" })
