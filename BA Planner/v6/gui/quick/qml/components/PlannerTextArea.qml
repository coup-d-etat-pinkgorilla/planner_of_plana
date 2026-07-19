import QtQuick
import QtQuick.Controls

TextArea {
    id: root
    required property QtObject designTokens
    ControlStyle { id: controlStyle; designTokens: root.designTokens; componentKey: "controls/input" }
    hoverEnabled: true

    leftPadding: 14
    rightPadding: 14
    topPadding: 12
    bottomPadding: 12
    color: designTokens.text
    placeholderTextColor: designTokens.muted
    selectionColor: designTokens.accent
    selectedTextColor: designTokens.backgroundDeep
    background: Rectangle {
        radius: controlStyle.radius
        color: controlStyle.colorFor(
            root.activeFocus ? controlStyle.activeSurface : root.hovered ? controlStyle.hoverSurface : controlStyle.normalSurface,
            root.designTokens.backgroundDeep
        )
        border.width: controlStyle.borderWidth
        border.color: root.activeFocus ? root.designTokens.accent : root.designTokens.border
    }
}
