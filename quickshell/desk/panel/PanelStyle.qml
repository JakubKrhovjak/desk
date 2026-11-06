pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Barvy panelu a bublin prostředí desk. Vypnutou průhlednost respektují.
Singleton {
    // Krytí bublin (stejné jako background-opacity v Ghostty), leží přes okna a musí zůstat čitelné
    readonly property real surfaceOpacity: 0.78
    readonly property color surface: translucent(surfaceOpacity)
    // Krytí panelu, pod ním je jen tapeta. Musí být nad ignore_alpha jeho pravidla v hyprland.lua, jinak zmizí rozmazání.
    // Stejné krytí mají titulkové lišty oken (bar_color v bars.lua).
    readonly property real panelOpacity: 0.25
    readonly property color panelSurface: translucent(panelOpacity)

    function translucent(opacity: real): color {
        return Colours.tPalette.m3surface.a < 1 ? Qt.alpha(Colours.palette.m3surface, opacity) : Colours.palette.m3surface;
    }
}
