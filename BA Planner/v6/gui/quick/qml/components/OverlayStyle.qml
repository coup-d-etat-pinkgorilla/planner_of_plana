import QtQuick

QtObject {
    id: root
    required property QtObject designTokens
    required property string componentKey

    readonly property var runtime: typeof quickTheme !== "undefined" && quickTheme
        ? (quickTheme.components[componentKey] || ({})) : ({})
    readonly property real preferredWidth: runtime.preferredWidth !== undefined ? Number(runtime.preferredWidth) : 0
    readonly property real preferredHeight: runtime.preferredHeight !== undefined ? Number(runtime.preferredHeight) : 0
    readonly property real padding: runtime.padding !== undefined ? Number(runtime.padding) : 12
    readonly property real radius: runtime.radius !== undefined ? Number(runtime.radius) : designTokens.radiusLarge
    readonly property real borderWidth: runtime.borderWidth !== undefined ? Number(runtime.borderWidth) : 2
    readonly property string surface: runtime.surface || "panelAlt"
    readonly property string borderSurface: runtime.borderSurface || "accent"
    readonly property string scrimSurface: runtime.scrimSurface || "backgroundDeep"
    readonly property real scrimOpacity: runtime.scrimOpacity !== undefined ? Number(runtime.scrimOpacity) : 0.5

    function colorFor(token, fallback) {
        const value = designTokens[token]
        return value !== undefined ? value : fallback
    }
}
