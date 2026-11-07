-- Společné nastavení prostředí desk: co se může změnit nebo používá víc souborů, patří sem.
local home = os.getenv("HOME")
local xdg_state = os.getenv("XDG_STATE_HOME")
-- Osobní nastavení mimo git (stránky Nastavení zapisují sem); výchozí hodnoty jsou v desk/defaults/state, doplňuje je start.sh.
-- Výchozí kopie pro běh mimo session jsou v nightshift.sh a ShellEnv.qml
local state_dir = (xdg_state and xdg_state ~= "" and xdg_state or home .. "/.local/state") .. "/desk"

-- Soubor generuje stránka Displays; chyba v něm nesmí vzít přihlášení, jako u colours.lua
local function load_monitors()
    local loaded, monitors = pcall(dofile, state_dir .. "/monitor-settings.lua")
    local valid = loaded and type(monitors) == "table" and type(monitors.main) == "string"
        and type(monitors.side) == "string" and type(monitors.outputs) == "table"
    return valid and monitors or { main = "HDMI-A-1", side = "DP-1", outputs = {} }
end

-- Klávesnice a myš ze stránky Keyboard & mouse (services/DeskInput.qml zapisuje JSON, Lua JSON neumí, proto vzory).
-- Meze a výchozí hodnoty odpovídají DeskInput.limits; poškozený nebo chybějící soubor dá výchozí hodnoty.
local input_limits = {
    sensitivity = { from = -1, to = 1, initial = 0 },
    repeatDelay = { from = 150, to = 1000, initial = 250 },
    repeatRate = { from = 10, to = 60, initial = 35 },
}

local function load_input(path)
    local file = io.open(path, "r")
    local text = file and file:read("a") or ""
    if file then
        file:close()
    end
    local function number(key)
        local limit = input_limits[key]
        local value = tonumber(text:match('"' .. key .. '"%s*:%s*(%-?[%d.]+)'))
        return value and math.max(limit.from, math.min(limit.to, value)) or limit.initial
    end
    local input = {}
    input.sensitivity = number("sensitivity")
    input.repeat_delay = math.floor(number("repeatDelay"))
    input.repeat_rate = math.floor(number("repeatRate"))
    input.accel_profile = text:match('"acceleration"%s*:%s*false') and "flat" or "adaptive"
    input.natural_scroll = text:match('"naturalScroll"%s*:%s*true') ~= nil
    return input
end

local config = {
    dir = home .. "/.config/desk",

    state_dir = state_dir,
    input = load_input(state_dir .. "/input-settings.json"),

    -- main je monitor s panelem; hodnoty nastavuje stránka Displays v Nastavení
    monitors = load_monitors(),

    gaps = {
        windows = 0, -- mezi okny; hranici tvoří jejich modrý okraj
        edge = 1, -- mezi okny a okrajem plochy; šířka okraje okna (border_size), jinak by modrý okraj vyjel z obrazovky
    },

    window_rounding = 15,

    classes = {
        terminal = "com.mitchellh.ghostty",
        toolbox = "jetbrains-toolbox",
        idea = "jetbrains-idea",
        shell = "org.quickshell",
    },

    -- Výchozí kopie pro běh mimo session jsou v autostart.sh a ShellEnv.qml
    minimized_workspace = "special:minimized",
}

-- Příkaz pro běžící shell, třeba config.shell_ipc("launcher toggle")
function config.shell_ipc(args)
    return "qs -c desk ipc call " .. args
end

-- Krytí v procentech: meze odpovídají minPanelOpacity a maxPanelOpacity v services/DeskPanelSettings.qml.
-- Svírá se, aby neplatné číslo nezastavilo načítání konfigurace.
function config.clamp_opacity(percent)
    return math.max(25, math.min(100, percent))
end

-- Krytí ze stránky Panels (services/DeskPanelSettings.qml zapisuje panel-settings.json ve stavové složce)
function config.saved_opacity(key, default)
    local file = io.open(config.state_dir .. "/panel-settings.json", "r")
    if not file then
        return default
    end
    local text = file:read("a")
    file:close()
    return config.clamp_opacity(tonumber(text:match('"' .. key .. '"%s*:%s*(%d+)')) or default)
end

-- Regulární výraz přesně na daný text, do pravidel oken
function config.exact_match(text)
    return "^" .. text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?{}|\\]", "\\%0") .. "$"
end

return config
