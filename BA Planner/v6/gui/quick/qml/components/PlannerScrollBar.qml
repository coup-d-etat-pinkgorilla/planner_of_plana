import QtQuick
import QtQuick.Controls

ScrollBar {
    id: root
    required property QtObject designTokens
    ControlStyle { id: controlStyle; designTokens: root.designTokens; componentKey: "controls/scrollbar" }
    readonly property real effectivePreferredWidth: controlStyle.preferredWidth
    readonly property real effectivePreferredHeight: controlStyle.preferredHeight
    readonly property real effectiveRadius: controlStyle.radius
    readonly property real effectiveBorderWidth: controlStyle.borderWidth
    readonly property string effectiveNormalSurface: controlStyle.normalSurface
    readonly property string effectiveHoverSurface: controlStyle.hoverSurface
    readonly property string effectiveActiveSurface: controlStyle.activeSurface
    readonly property string effectivePressedSurface: controlStyle.pressedSurface
    readonly property string effectiveSurface: pressed ? effectivePressedSurface
        : hovered ? effectiveHoverSurface
        : active ? effectiveActiveSurface : effectiveNormalSurface

    hoverEnabled: true
    implicitWidth: effectivePreferredWidth > 0 ? effectivePreferredWidth : 10
    implicitHeight: effectivePreferredHeight > 0 ? effectivePreferredHeight : 0
    padding: 2
    contentItem: Rectangle {
        implicitWidth: 6
        radius: root.effectiveRadius
        color: controlStyle.colorFor(root.effectiveSurface, root.designTokens.border)
        border.width: root.effectiveBorderWidth
        border.color: root.designTokens.border
        opacity: root.active ? 1.0 : 0.55
    }
    background: Rectangle {
        color: root.designTokens.backgroundDeep
        radius: root.effectiveRadius
        opacity: 0.45
    }
}
