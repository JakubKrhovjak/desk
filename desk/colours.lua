-- Barvy ze schématu Caelestie. Její soubor vzniká až za běhu Hyprlandu s Lua konfigurací,
-- takže na čisté instalaci chybí a bez záložních hodnot by první přihlášení skončilo bez panelu i zkratek.
local fallback = {
    primary = "afc9eb",
    onPrimary = "28425e",
    inversePrimary = "48617f",
    surface = "0c0e12",
    onSurface = "e1e5ef",
    onSurfaceVariant = "a7abb4",
    surfaceContainer = "161a1f",
    surfaceContainerHighest = "21262d",
}

local loaded, scheme = pcall(require, "scheme.current")
return loaded and scheme or fallback
