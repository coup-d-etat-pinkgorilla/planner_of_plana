import QtQuick

QtObject {
    id: root
    required property QtObject designTokens
    required property string componentKey

    readonly property var runtime: typeof quickTheme !== "undefined" && quickTheme
        ? (quickTheme.components[componentKey] || ({})) : ({})
    readonly property real preferredHeight: runtime.preferredHeight !== undefined ? Number(runtime.preferredHeight) : 0
    readonly property var contentPadding: runtime.contentPadding || [0, 0, 0, 0]
    readonly property real radius: runtime.radius !== undefined ? Number(runtime.radius) : designTokens.radiusSmall
    readonly property real borderWidth: runtime.borderWidth !== undefined ? Number(runtime.borderWidth) : 1
    readonly property string normalSurface: runtime.normalSurface || "panel"
    readonly property string alternateSurface: runtime.alternateSurface || normalSurface
    readonly property string selectedSurface: runtime.selectedSurface || normalSurface
    readonly property string borderSurface: runtime.borderSurface || "border"
    readonly property string selectedBorderSurface: runtime.selectedBorderSurface || borderSurface

    function colorFor(token, fallback) {
        const value = designTokens[token]
        return value !== undefined ? value : fallback
    }
}
