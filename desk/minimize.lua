-- Minimalizace do skryté plochy, vracení oken a fokus po zavření okna.
local config = require("config")
local is_visible = require("geometry").is_visible

-- Minimalizace = skrytá speciální plocha. Hyprland ji ale ukáže, jakmile na ní něco dostane fokus,
-- a na ukázané ploše by minimalizace nic neschovala, proto ji hned zase skrývá.
local minimized_workspace = config.minimized_workspace

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
        if is_visible(win) and win.class ~= config.classes.toolbox
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
    hl.exec_cmd(string.format(config.shell_ipc("minimize animate %s %d %d %d %d"), address, win.at.x, win.at.y, win.size.x, win.size.y))
    minimize_timers[address] = hl.timer(function() finish_minimize(address) end, { timeout = minimize_fallback_ms, type = "oneshot" })
end

-- Třídy oken aplikací s ikonou v trayi; o trayi ví jen shell, posílá je z panel/PanelApps.qml.
local tray_classes = {}

function set_tray_classes(classes)
    tray_classes = {}
    for _, class in ipairs(classes) do
        tray_classes[class] = true
    end
end

-- Křížek v liště okna: aplikace s ikonou v trayi běží dál a okno se jen schová. Super + Q zavírá vždycky.
function close_active()
    local win = hl.get_active_window()
    if not win then return end

    if tray_classes[win.class] then
        minimize_active()
    else
        hl.dispatch(hl.dsp.window.close())
    end
end

-- Obnovení z panelu: shell přehraje animaci a na jejím konci zavolá finish_restore; pojistka vrátí okno i bez animace
local restore_fallback_ms = 900
local pending_restore = {}
local restore_timers = {}

-- Jediné místo, které vrací okno dopředu, volá se i ze shellu. Se zadanou plochou okno nejdřív přesune z minimalizace:
-- pořadí je důležité, fokus na okno ve skryté ploše by otevřel celou plochu.
function restore_window(address, workspace)
    local target = "address:" .. address
    if workspace then
        hl.dispatch(hl.dsp.window.move({ workspace = workspace, follow = false, window = target }))
    end
    hl.dispatch(hl.dsp.focus({ window = target }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end

function finish_restore(address)
    local workspace = pending_restore[address]
    if not workspace then return end
    pending_restore[address] = nil
    restore_timers[address] = nil

    restore_window(address, workspace)
end

function restore_minimized(address, workspace)
    if pending_restore[address] then return end

    pending_restore[address] = workspace
    hl.exec_cmd(config.shell_ipc("minimize restore " .. address))
    restore_timers[address] = hl.timer(function() finish_restore(address) end, { timeout = restore_fallback_ms, type = "oneshot" })
end

hl.on("workspace.special_active", hide_minimized)
