-- Chování oken běžící na pozadí: zvedání po fokusu a hlídání titulkových lišt.
local config = require("config")
local geometry = require("geometry")

local bar_height = geometry.bar_height

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
        if geometry.is_floating_on_desk(win) and win.title ~= "" and win.class ~= config.classes.toolbox then
            local top = mon.y + mon.reserved.top + bar_height
            if win.at.y < top then
                hl.dispatch(hl.dsp.window.move({ x = win.at.x, y = top, relative = false, window = win }))
            end
        end
    end
end

bars_timer = hl.timer(keep_bars_reachable, { timeout = 300, type = "repeat" })

-- Krytí oken shellu (Nastavení a Files) ze stránky Panels, položka Settings & Files; výchozí spojené s panelem.
-- Pozadí těch oken je neprůhledné, průhlednost dává jen tahle vlastnost okna.
local shell_opacity = config.saved_opacity("windowOpacity", config.saved_opacity("panelOpacity", 50))

local function apply_shell_opacity(win)
    hl.dispatch(hl.dsp.window.set_prop({ prop = "opacity", value = tostring(shell_opacity / 100), window = win }))
end

hl.on("window.open", function(win)
    if win.class == config.classes.shell then
        apply_shell_opacity(win)
    end
end)

-- Volá shell přes hyprctl eval při změně v Nastavení
function window_opacity(percent)
    shell_opacity = math.max(25, math.min(100, percent))
    for _, win in ipairs(hl.get_windows()) do
        if win.class == config.classes.shell then
            apply_shell_opacity(win)
        end
    end
end
