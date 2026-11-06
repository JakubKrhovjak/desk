-- Chování oken běžící na pozadí: zvedání po fokusu a hlídání titulkových lišt.
local config = require("config")
local bar_height = require("geometry").bar_height

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
            and win.title ~= "" and win.class ~= config.classes.toolbox then
            local top = mon.y + mon.reserved.top + bar_height
            if win.at.y < top then
                hl.dispatch(hl.dsp.window.move({ x = win.at.x, y = top, relative = false, window = win }))
            end
        end
    end
end

bars_timer = hl.timer(keep_bars_reachable, { timeout = 300, type = "repeat" })
