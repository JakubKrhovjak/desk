-- Titulkové lišty oken (plugin hyprbars). Po aktualizaci Hyprlandu je potřeba plugin znovu zkompilovat,
-- jinak se nenačte a okna budou jen bez lišt, zbytek prostředí poběží dál.
local bars = {}
local config = require("config")

bars.height = 0

local loaded = pcall(hl.plugin.load, config.dir .. "/plugins/hyprbars.so")
if not loaded or not (hl.plugin.hyprbars and hl.plugin.hyprbars.add_button) then
    return bars
end

local scheme = require("colours")

bars.height = 30

-- Okno připnuté navrch je poznat na první pohled: lišta v barvě zvýraznění a silnější rámeček
hl.window_rule({
    match = { pin = true },
    border_size = 3,
    ["hyprbars:bar_color"] = "rgb(" .. scheme.primary .. ")",
    ["hyprbars:title_color"] = "rgb(" .. scheme.onPrimary .. ")",
})

hl.config({
    plugin = {
        hyprbars = {
            bar_height = bars.height,
            bar_color = "rgb(" .. scheme.surfaceContainer .. ")",
            ["col.text"] = "rgb(" .. scheme.onSurface .. ")",
            bar_text_size = 11,
            bar_text_font = "Google Sans Flex",
            bar_text_align = "center",
            bar_buttons_alignment = "left", -- ovládání okna vlevo jako na Macu
            bar_padding = 12,
            bar_button_padding = 8,
            bar_part_of_window = true,
            bar_precedence_over_border = true,
            on_double_click = "hyprctl eval 'toggle_maximize()'",
        },
    },
})

local function add_button(icon, action)
    hl.plugin.hyprbars.add_button({
        bg_color = "rgb(" .. scheme.surfaceContainerHighest .. ")",
        fg_color = "rgb(" .. scheme.onSurface .. ")",
        size = 18,
        icon = icon,
        action = action,
    })
end

-- Pořadí zleva: zavřít, minimalizovat, maximalizovat
add_button("✕", "hyprctl eval 'hl.dispatch(hl.dsp.window.close())'")
add_button("–", "hyprctl eval 'minimize_active()'")
add_button("▢", "hyprctl eval 'toggle_maximize()'")

return bars
