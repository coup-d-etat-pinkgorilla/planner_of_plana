import QtQuick

Rectangle {
    id: root
    required property QtObject designTokens
    required property string componentKey

    ElementStyle { id: elementStyle; designTokens: root.designTokens; componentKey: root.componentKey }
    readonly property real effectivePreferredWidth: elementStyle.preferredWidth
    readonly property real effectivePreferredHeight: elementStyle.preferredHeight
    readonly property real effectiveRadius: elementStyle.radius
    readonly property real effectiveBorderWidth: elementStyle.borderWidth
    readonly property string effectiveSurface: elementStyle.surface
    readonly property string effectiveBorderSurface: elementStyle.borderSurface
    readonly property real effectiveOpacity: elementStyle.elementOpacity

    radius: effectiveRadius
    color: elementStyle.colorFor(effectiveSurface, designTokens.backgroundDeep)
    border.width: effectiveBorderWidth
    border.color: elementStyle.colorFor(effectiveBorderSurface, designTokens.border)
    opacity: effectiveOpacity
}
