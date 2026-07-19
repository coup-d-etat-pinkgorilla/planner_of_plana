import QtQuick

QtObject {
    id: root
    required property QtObject designTokens
    required property string componentKey

    readonly property var runtime: typeof quickTheme !== "undefined" && quickTheme
        ? (quickTheme.components[componentKey] || ({})) : ({})
    readonly property real preferredWidth: runtime.preferredWidth !== undefined ? Number(runtime.preferredWidth) : 0
    readonly property real preferredHeight: runtime.preferredHeight !== undefined ? Number(runtime.preferredHeight) : 48
    readonly property real radius: runtime.radius !== undefined ? Number(runtime.radius) : designTokens.radiusSmall
    readonly property real borderWidth: runtime.borderWidth !== undefined ? Number(runtime.borderWidth) : 1
    readonly property string normalSurface: runtime.normalSurface || "backgroundDeep"
    readonly property string hoverSurface: runtime.hoverSurface || "panelRaised"
    readonly property string activeSurface: runtime.activeSurface || "accent"
    readonly property string pressedSurface: runtime.pressedSurface || "accentStrong"

    function colorFor(surface, fallback) {
        const value = designTokens[surface]
        return value !== undefined ? value : fallback
    }

    function foregroundFor(surface) {
        return surface === "accent" || surface === "accentStrong"
            ? designTokens.backgroundDeep : designTokens.text
    }
}
