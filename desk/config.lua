-- Společné nastavení prostředí desk: co se může změnit nebo používá víc souborů, patří sem.
local dir = os.getenv("HOME") .. "/.config/desk"

local config = {
    dir = dir,

    monitors = {
        main = "HDMI-A-1", -- s panelem
        side = "DP-1",
    },

    gaps = {
        windows = 10, -- mezi okny
        edge = 5, -- mezi okny a okrajem plochy
    },

    classes = {
        terminal = "com.mitchellh.ghostty",
        toolbox = "jetbrains-toolbox",
        idea = "jetbrains-idea",
        shell = "org.quickshell",
    },

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
