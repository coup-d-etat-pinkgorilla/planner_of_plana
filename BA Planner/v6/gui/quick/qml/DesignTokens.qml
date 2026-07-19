import QtQuick

QtObject {
    readonly property var runtime: (typeof quickTheme !== "undefined" && quickTheme) ? quickTheme.tokens : ({})
    readonly property color background: runtime.background || "#171c2b"
    readonly property color backgroundAlt: runtime.backgroundAlt || "#2c3140"
    readonly property color backgroundDeep: runtime.backgroundDeep || "#111522"
    readonly property color panel: runtime.panel || "#313b59"
    readonly property color panelAlt: runtime.panelAlt || "#2c3140"
    readonly property color panelRaised: runtime.panelRaised || "#3a4566"
    readonly property color surfaceSelected: runtime.surfaceSelected || "#654665"
    readonly property color accent: runtime.accent || "#f266b3"
    readonly property color accentStrong: runtime.accentStrong || "#f57fc0"
    readonly property color accentSoft: runtime.accentSoft || "#844d72"
    readonly property color accentPale: runtime.accentPale || "#9a8c9d"
    readonly property color text: runtime.text || "#f2f2f2"
    readonly property color muted: runtime.muted || "#a6a9b5"
    readonly property color border: runtime.border || "#5c5960"
    readonly property color shadow: runtime.shadow || "#1d202a"
    readonly property color danger: runtime.danger || "#ef6a78"
    readonly property color warning: runtime.warning || "#f0bd67"
    readonly property color success: runtime.success || "#68d0a4"

    readonly property int fontCaption: runtime.fontCaption || 14
    readonly property int fontBody: runtime.fontBody || 18
    readonly property int fontSection: runtime.fontSection || 24
    readonly property int fontTitle: runtime.fontTitle || 34
    readonly property int spacingSmall: 8
    readonly property int spacingMedium: 16
    readonly property int spacingLarge: 24
    readonly property int radiusSmall: 8
    readonly property int radiusPanel: 18
}
