-- Společné nastavení prostředí desk: co se může změnit nebo používá víc souborů, patří sem.
local home = os.getenv("HOME")
local xdg_state = os.getenv("XDG_STATE_HOME")

-- Soubor se přepisuje za běhu a je ve verzovacím systému; chyba v něm nesmí vzít přihlášení, jako u colours.lua
local function load_monitors()
    local loaded, monitors = pcall(require, "monitor-settings")
    local valid = loaded and type(monitors) == "table" and type(monitors.main) == "string"
        and type(monitors.side) == "string" and type(monitors.outputs) == "table"
    return valid and monitors or { main = "HDMI-A-1", side = "DP-1", outputs = {} }
end

-- Klávesnice a myš ze stránky Keyboard & mouse (services/DeskInput.qml zapisuje JSON, Lua JSON neumí, proto vzory).
-- Hodnoty se svírají stejně jako v DeskInput.qml, poškozený nebo chybějící soubor dá výchozí hodnoty.
local function load_input(path)
    local input = { sensitivity = 0, accel_profile = "adaptive", natural_scroll = false, repeat_delay = 250, repeat_rate = 35 }
    local file = io.open(path, "r")
    if not file then
        return input
    end
    local text = file:read("a")
    file:close()
    local function number(key, low, high, default)
        local value = tonumber(text:match('"' .. key .. '"%s*:%s*(%-?[%d.]+)'))
        return value and math.max(low, math.min(high, value)) or default
    end
    input.sensitivity = number("sensitivity", -1, 1, 0)
    input.repeat_delay = math.floor(number("repeatDelay", 150, 1000, 250))
    input.repeat_rate = math.floor(number("repeatRate", 10, 60, 35))
    input.accel_profile = text:match('"acceleration"%s*:%s*false') and "flat" or "adaptive"
    input.natural_scroll = text:match('"naturalScroll"%s*:%s*true') ~= nil
    return input
end

local config = {
    dir = home .. "/.config/desk",

    input = load_input(home .. "/.config/desk/input-settings.json"),
    -- Výchozí kopie pro běh mimo session jsou v nightshift.sh a ShellEnv.qml
    state_dir = (xdg_state ~= "" and xdg_state or home .. "/.local/state") .. "/desk",

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

-- Krytí v procentech ze stránky Panels (services/DeskPanelSettings.qml zapisuje desk/panel-settings.json).
-- Hodnota se svírá, aby neplatné číslo nezastavilo načítání konfigurace; spodní mez je minPanelOpacity.
function config.saved_opacity(key, default)
    local file = io.open(config.dir .. "/panel-settings.json", "r")
    if not file then
        return default
    end
    local text = file:read("a")
    file:close()
    local opacity = tonumber(text:match('"' .. key .. '"%s*:%s*(%d+)')) or default
    return math.max(25, math.min(100, opacity))
end

-- Regulární výraz přesně na daný text, do pravidel oken
function config.exact_match(text)
    return "^" .. text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?{}|\\]", "\\%0") .. "$"
end

return config
