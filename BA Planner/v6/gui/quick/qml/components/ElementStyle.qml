import QtQuick

QtObject {
    id: root
    required property QtObject designTokens
    required property string componentKey

    readonly property var runtime: typeof quickTheme !== "undefined" && quickTheme
        ? (quickTheme.components[componentKey] || ({})) : ({})
    readonly property real preferredWidth: runtime.preferredWidth !== undefined ? Number(runtime.preferredWidth) : 0
    readonly property real preferredHeight: runtime.preferredHeight !== undefined ? Number(runtime.preferredHeight) : 0
    readonly property real radius: runtime.radius !== undefined ? Number(runtime.radius) : 0
    readonly property real borderWidth: runtime.borderWidth !== undefined ? Number(runtime.borderWidth) : 0
    readonly property string surface: runtime.surface || "backgroundDeep"
    readonly property string borderSurface: runtime.borderSurface || "border"
    readonly property real elementOpacity: runtime.opacity !== undefined ? Number(runtime.opacity) : 1

    function colorFor(token, fallback) {
        const value = designTokens[token]
        return value !== undefined ? value : fallback
    }
}
