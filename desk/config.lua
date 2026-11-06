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

local config = {
    dir = home .. "/.config/desk",
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

-- Regulární výraz přesně na daný text, do pravidel oken
function config.exact_match(text)
    return "^" .. text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?{}|\\]", "\\%0") .. "$"
end

return config
