import QtQuick
import QtQuick.Controls

CheckBox {
    id: root
    required property QtObject designTokens
    ControlStyle { id: controlStyle; designTokens: root.designTokens; componentKey: "controls/checkbox" }
    readonly property real effectivePreferredWidth: controlStyle.preferredWidth
    readonly property real effectivePreferredHeight: controlStyle.preferredHeight
    readonly property real effectiveRadius: controlStyle.radius
    readonly property real effectiveBorderWidth: controlStyle.borderWidth
    readonly property string effectiveNormalSurface: controlStyle.normalSurface
    readonly property string effectiveHoverSurface: controlStyle.hoverSurface
    readonly property string effectiveActiveSurface: controlStyle.activeSurface
    readonly property string effectivePressedSurface: controlStyle.pressedSurface
    readonly property string effectiveSurface: down ? effectivePressedSurface
        : checked ? effectiveActiveSurface
        : hovered ? effectiveHoverSurface : effectiveNormalSurface

    hoverEnabled: true
    spacing: 10
    indicator: Rectangle {
        implicitWidth: root.effectivePreferredWidth > 0 ? root.effectivePreferredWidth : 24
        implicitHeight: root.effectivePreferredHeight > 0 ? root.effectivePreferredHeight : 24
        x: root.leftPadding
        y: (root.height - height) / 2
        radius: root.effectiveRadius
        color: controlStyle.colorFor(root.effectiveSurface, root.designTokens.backgroundDeep)
        border.width: root.effectiveBorderWidth
        border.color: root.checked ? root.designTokens.accentStrong : root.designTokens.border
        Text {
            anchors.centerIn: parent
            visible: root.checked
            text: "✓"
            color: controlStyle.foregroundFor(root.effectiveSurface)
            font.pixelSize: 17
            font.bold: true
        }
    }
    contentItem: Text {
        leftPadding: root.indicator.width + root.spacing
        text: root.text
        color: root.designTokens.text
        font: root.font
        verticalAlignment: Text.AlignVCenter
    }
}
