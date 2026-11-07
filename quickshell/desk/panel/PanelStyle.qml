pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Barvy panelu a bublin prostředí desk. Vypnutou průhlednost respektují.
Singleton {
    // Krytí bublin, leží přes okna a musí zůstat čitelné
    readonly property real surfaceOpacity: 0.78
    readonly property color surface: translucent(surfaceOpacity)
    // Krytí panelu nastavuje stránka Panels v Nexusu.
    // Titulkové lišty oken mají stejnou barvu (bar_color v bars.lua), krytí je s panelem spojené, jde ale nastavit zvlášť.
    readonly property real panelOpacity: DeskPanelSettings.panelOpacity / 100
    readonly property color panelSurface: translucent(panelOpacity, Colours.palette.m3secondaryContainer)

    function translucent(opacity: real, base = Colours.palette.m3surface): color {
        return Colours.tPalette.m3surface.a < 1 ? Qt.alpha(base, opacity) : base;
    }
}
