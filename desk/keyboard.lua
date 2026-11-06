-- Klávesa Command jako na Macu: chování v keyd se přepíná podle aktivního okna (keyd-mode.sh).
local script = os.getenv("HOME") .. "/.config/desk/keyd-mode.sh"

local modes = {
    ["com.mitchellh.ghostty"] = "ghostty",
    ["jetbrains-idea"] = "idea",
}

local current

local function apply_mode(win)
    local mode = win and modes[win.class] or "base"
    if mode ~= current then
        current = mode
        hl.exec_cmd(script .. " " .. mode)
    end
end

-- Keyd je společný pro celý systém, takže ve vnořeném testu v Plasmě se nepřepíná
if not os.getenv("DESK_NESTED") then
    hl.on("window.active", apply_mode)
    apply_mode(hl.get_active_window())

    -- Při načítání konfigurace po přihlášení ještě nemusí jít spouštět příkazy, proto se režim nastaví i po startu
    hl.on("hyprland.start", function()
        current = nil
        apply_mode(hl.get_active_window())
    end)
end
