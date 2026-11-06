-- Výpočty poloh a stav oken, které používají ostatní moduly.
local config = require("config")

local snap_gap = config.gaps.windows
local outer_gap = config.gaps.edge
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

-- Pracovní plocha monitoru bez panelu a s mezerou kolem. Parametr top počítá s jinou výškou panelu, než je teď.
local function monitor_snap_rect(mon, side, top)
    local res = mon.reserved
    top = top or res.top

    local rect = snap_rect(
        side,
        mon.x + res.left + outer_gap,
        mon.y + top + outer_gap,
        math.floor(mon.width / mon.scale - res.left - res.right - 2 * outer_gap),
        math.floor(mon.height / mon.scale - top - res.bottom - 2 * outer_gap)
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

-- Celá pracovní plocha monitoru pod panelem
local function maximized_rect(mon, top)
    local res = mon.reserved
    top = top or res.top

    return {
        x = mon.x + res.left + outer_gap,
        y = mon.y + top + outer_gap + bar_height,
        w = math.floor(mon.width / mon.scale - res.left - res.right - 2 * outer_gap),
        h = math.floor(mon.height / mon.scale - top - res.bottom - 2 * outer_gap) - bar_height,
    }
end

local function is_visible(win)
    local mon = win.monitor
    return win.mapped and not win.hidden and win.workspace and mon
        and (win.pinned or (mon.active_workspace and win.workspace.id == mon.active_workspace.id))
end

-- Plovoucí okno na běžné ploše: ne skryté, minimalizované ani přes celou obrazovku
local function is_floating_on_desk(win)
    local on_special = win.workspace and win.workspace.name:find("special", 1, true)
    local fullscreen = win.fullscreen and win.fullscreen ~= 0
    return win.monitor and win.floating and not win.hidden and not on_special and not fullscreen
end

return {
    is_floating_on_desk = is_floating_on_desk,
    bar_height = bar_height,
    monitor_snap_rect = monitor_snap_rect,
    maximized_rect = maximized_rect,
    is_at = is_at,
    neighbour_monitor = neighbour_monitor,
    apply_rect = apply_rect,
    is_visible = is_visible,
}
