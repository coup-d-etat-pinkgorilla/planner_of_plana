import QtQuick
import QtQuick.Controls

ProgressBar {
    id: root
    required property QtObject designTokens
    ControlStyle { id: controlStyle; designTokens: root.designTokens; componentKey: "controls/progress" }
    readonly property real effectivePreferredWidth: controlStyle.preferredWidth
    readonly property real effectivePreferredHeight: controlStyle.preferredHeight
    readonly property real effectiveRadius: controlStyle.radius
    readonly property real effectiveBorderWidth: controlStyle.borderWidth
    readonly property string effectiveNormalSurface: controlStyle.normalSurface
    readonly property string effectiveHoverSurface: controlStyle.hoverSurface
    readonly property string effectiveActiveSurface: controlStyle.activeSurface
    readonly property string effectivePressedSurface: controlStyle.pressedSurface

    implicitWidth: effectivePreferredWidth > 0 ? effectivePreferredWidth : 0
    implicitHeight: effectivePreferredHeight > 0 ? effectivePreferredHeight : 12
    background: Rectangle {
        implicitHeight: root.implicitHeight
        radius: root.effectiveRadius
        color: controlStyle.colorFor(root.effectiveNormalSurface, root.designTokens.backgroundDeep)
        border.width: root.effectiveBorderWidth
        border.color: root.designTokens.border
    }
    contentItem: Item {
        implicitHeight: root.implicitHeight
        Rectangle {
            width: parent.width * root.visualPosition
            height: parent.height
            radius: root.effectiveRadius
            color: controlStyle.colorFor(root.effectiveActiveSurface, root.designTokens.accent)
        }
    }
}
