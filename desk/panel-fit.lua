-- Okna po změně výšky panelu. Při zvětšení je Hyprland posune dolů o rozdíl, při zmenšení je nevrátí a o paměti oken neví.
local config = require("config")
local geometry = require("geometry")
local memory = require("window-memory")

local monitor_snap_rect = geometry.monitor_snap_rect
local maximized_rect = geometry.maximized_rect

local tolerance = 2

local function near(a, b)
    return math.abs(a - b) <= tolerance
end

-- Rozměry, které mají okna přichycená k okrajům plochy, pro danou výšku panelu
local function anchored_rects(mon, top)
    local left = monitor_snap_rect(mon, "left", top)
    local right = monitor_snap_rect(mon, "right", top)
    return {
        maximized_rect(mon, top),
        left,
        right,
        monitor_snap_rect(mon, "up", top),
        monitor_snap_rect(mon, "down", top),
        { x = left.x, y = left.y, w = right.x + right.w - left.x, h = left.h }, -- roztažené na celou šířku
    }
end

-- Přichycené okno dostane stejné místo pro novou výšku, ostatní se jen vejde do plochy
local function fitted_rect(mon, old_top, rect)
    local new_top = mon.reserved.top
    local pushed = new_top - old_top
    local old_rects = anchored_rects(mon, old_top)
    local new_rects = anchored_rects(mon, new_top)

    for index, old in ipairs(old_rects) do
        if near(rect.x, old.x) and near(rect.w, old.w) and near(rect.h, old.h)
            and (near(rect.y, old.y) or near(rect.y, old.y + pushed)) then
            return new_rects[index]
        end
    end

    local work = maximized_rect(mon)
    local bottom = work.y + work.h
    local h = math.min(rect.h, work.h)
    local y = math.min(math.max(rect.y, work.y), bottom - h)
    return { x = rect.x, y = y, w = rect.w, h = h }
end

-- Volá shell po změně výšky, až když ji Hyprland převzal do mon.reserved
function fit_windows_to_panel(old_top)
    local mon
    for _, candidate in ipairs(hl.get_monitors()) do
        if candidate.name == config.monitors.main then mon = candidate end
    end
    if not mon then return end

    for _, win in ipairs(hl.get_windows()) do
        if geometry.is_floating_on_desk(win) and win.monitor.name == mon.name and win.class ~= config.classes.toolbox then
            local rect = fitted_rect(mon, old_top, { x = win.at.x, y = win.at.y, w = win.size.x, h = win.size.y })
            geometry.apply_rect(win, rect.x, rect.y, rect.w, rect.h)
        end
    end

    memory.refit(mon.name, function(rect)
        local fitted = fitted_rect(mon, old_top, { x = rect.x + mon.x, y = rect.y + mon.y, w = rect.w, h = rect.h })
        return { x = fitted.x - mon.x, y = fitted.y - mon.y, w = fitted.w, h = fitted.h }
    end)
end
