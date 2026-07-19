import QtQuick
import QtQuick.Controls

Button {
    id: root
    required property QtObject designTokens
    property bool active: false
    property string variant: "normal"

    hoverEnabled: true
    implicitWidth: 96
    ControlStyle { id: controlStyle; designTokens: root.designTokens; componentKey: "controls/button" }
    readonly property real effectivePreferredHeight: controlStyle.preferredHeight
    readonly property real effectiveRadius: controlStyle.radius
    readonly property real effectiveBorderWidth: controlStyle.borderWidth
    readonly property string effectiveNormalSurface: controlStyle.normalSurface
    readonly property string effectiveHoverSurface: controlStyle.hoverSurface
    readonly property string effectiveActiveSurface: controlStyle.activeSurface
    readonly property string effectivePressedSurface: controlStyle.pressedSurface
    readonly property string effectiveSurface: down ? controlStyle.pressedSurface
        : variant === "danger" ? "danger"
        : active || variant === "accent" ? controlStyle.activeSurface
        : hovered ? controlStyle.hoverSurface
        : controlStyle.normalSurface

    implicitHeight: effectivePreferredHeight
    padding: 12

    contentItem: Text {
        text: root.text
        color: controlStyle.foregroundFor(root.effectiveSurface)
        font: root.font
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        radius: controlStyle.radius
        color: controlStyle.colorFor(root.effectiveSurface, root.designTokens.panel)
        border.width: controlStyle.borderWidth
        border.color: root.active || root.variant === "danger" ? root.designTokens.accentStrong : root.designTokens.border
    }
}
