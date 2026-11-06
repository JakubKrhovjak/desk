-- Kde se okna aplikací otevírají poprvé; potom má přednost paměť oken (window-memory.lua).
local config = require("config")
local geometry = require("geometry")
local window_memory = require("window-memory")
local toolbox_rect = require("toolbox").rect

local snap_gap = config.gaps.windows
local outer_gap = config.gaps.edge
local bar_height = geometry.bar_height
local monitor_snap_rect = geometry.monitor_snap_rect
local maximized_rect = geometry.maximized_rect
local apply_rect = geometry.apply_rect
local terminal_class = config.classes.terminal

-- IntelliJ se pozná až podle titulku s projektem, aby se nemaximalizovaly i jeho dialogy (mají stejnou třídu okna).
-- Půlka vedlejšího monitoru (nemá panel, proto stačí počítat s lištou a mezerou). Z jednoho popisu vznikne
-- pravidlo pro vznik okna i přesný rozměr pro place_on_open, aby se obojí nemohlo rozejít.
local function half_of_side_monitor(class, title_field, title, side)
    local half_width = "((monitor_w-" .. (2 * outer_gap + snap_gap) .. ")/2)"
    local half_height = "(monitor_h-" .. (2 * outer_gap + bar_height) .. ")"
    local x = side == "left" and tostring(outer_gap) or "(monitor_w-" .. outer_gap .. "-" .. half_width .. ")"

    return {
        matches = function(win) return win.class == class and win[title_field] == title end,
        monitor = config.monitors.side,
        rect = function(mon) return monitor_snap_rect(mon, side) end,
        rule = {
            match = { class = config.exact_match(class), [title_field] = config.exact_match(title) },
            size = half_width .. " " .. half_height,
            move = x .. " " .. (outer_gap + bar_height),
        },
    }
end

local home_places = {
    {
        matches = function(win)
            return win.class == config.classes.idea and (win.title:find(" – ", 1, true) or win.title == "Welcome to IntelliJ IDEA")
        end,
        monitor = config.monitors.main,
        rect = maximized_rect,
        rule = { match = { class = config.exact_match(config.classes.idea) } },
    },
    half_of_side_monitor(terminal_class, "initial_title", "Ghostty", "right"),
    half_of_side_monitor(config.classes.shell, "title", "Files", "left"),
    {
        -- Toolbox se sám otevírá na y = 0, pod panelem; patří vpravo nahoře pod panel a velikost si drží svou
        matches = function(win) return win.class == config.classes.toolbox end,
        monitor = config.monitors.main,
        rect = toolbox_rect,
        rule = { match = { class = config.exact_match(config.classes.toolbox) } },
    },
}

-- Pravidla platí už při vzniku okna, takže okno neproblikne jinde a nepřeskakuje mezi monitory
for _, place in ipairs(home_places) do
    place.rule.monitor = place.monitor
    hl.window_rule(place.rule)
end

-- Každé okno se umístí jen jednou. Okna otevřená před načtením konfigurace se nepřesouvají.
local placed = {}
for _, win in ipairs(hl.get_windows()) do
    placed[win.address] = true
end

local function place_on_open(win)
    if placed[win.address] then return end

    -- Zapamatovaná poloha má přednost, výchozí místo platí jen při prvním otevření aplikace
    if window_memory.has(win) then
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
    if win and win.class == config.classes.toolbox then
        placed[win.address] = nil
        place_on_open(win)
    end
end)
