-- JetBrains Toolbox jako vyskakovací panel u ikony v trayi.
local config = require("config")
local bar_height = require("geometry").bar_height

local snap_gap = config.gaps.windows

local function toolbox_rect(mon, win)
    local res = mon.reserved
    return {
        x = math.floor(mon.x + mon.width / mon.scale - res.right - win.size.x - snap_gap),
        y = mon.y + res.top + snap_gap,
        w = win.size.x,
        h = win.size.y,
    }
end

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
        if win.class == config.classes.toolbox then
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
    local home = hl.get_monitor(config.monitors.main)
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
    if win and win.class == config.classes.toolbox and not toolbox_timer:is_enabled() then
        toolbox_entered = false
        toolbox_outside_ms = 0
        toolbox_timer:set_enabled(true)
    end
end

hl.on("window.open", watch_toolbox)
hl.on("window.active", watch_toolbox)

return { rect = toolbox_rect }
