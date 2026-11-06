-- Rozložení monitorů. Soubor generuje stránka Displays v Nastavení, ruční úpravy přepíše.
return {
    main = "HDMI-A-1",
    side = "DP-1",
    outputs = {
        { name = "DP-1", mode = "2560x1440@164.96", x = 2560, y = 0, scale = 1, transform = 0, disabled = false },
        { name = "HDMI-A-1", mode = "2560x1440@143.93", x = 0, y = 0, scale = 1, transform = 0, disabled = false },
    },
}
