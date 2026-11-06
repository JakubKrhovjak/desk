-- Přichycení oken na půlky, roztažení a maximalizace.
local geometry = require("geometry")

local monitor_snap_rect = geometry.monitor_snap_rect
local maximized_rect = geometry.maximized_rect
local is_at = geometry.is_at
local neighbour_monitor = geometry.neighbour_monitor
local apply_rect = geometry.apply_rect

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

local function arrow_pressed(side)
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

return { arrow_pressed = arrow_pressed }
