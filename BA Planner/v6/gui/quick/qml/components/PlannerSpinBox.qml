import QtQuick
import QtQuick.Controls

SpinBox {
    id: root
    required property QtObject designTokens
    ControlStyle { id: controlStyle; designTokens: root.designTokens; componentKey: "controls/input" }

    editable: true
    implicitWidth: 112
    implicitHeight: controlStyle.preferredHeight
    leftPadding: 12
    rightPadding: 58

    contentItem: TextInput {
        z: 2
        text: root.textFromValue(root.value, root.locale)
        color: root.designTokens.text
        selectionColor: root.designTokens.accent
        selectedTextColor: root.designTokens.backgroundDeep
        horizontalAlignment: Qt.AlignHCenter
        verticalAlignment: Qt.AlignVCenter
        readOnly: !root.editable
        validator: root.validator
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        font: root.font
    }

    up.indicator: Rectangle {
        x: root.width - width
        height: root.height
        implicitWidth: 28
        color: root.up.pressed ? root.designTokens.accent : root.designTokens.panelRaised
        border.color: root.designTokens.border
        radius: root.designTokens.radiusSmall
        Text { anchors.centerIn: parent; text: "+"; color: root.designTokens.text; font.bold: true }
    }
    down.indicator: Rectangle {
        x: root.width - 56
        height: root.height
        implicitWidth: 28
        color: root.down.pressed ? root.designTokens.accent : root.designTokens.panelRaised
        border.color: root.designTokens.border
        radius: root.designTokens.radiusSmall
        Text { anchors.centerIn: parent; text: "−"; color: root.designTokens.text; font.bold: true }
    }
    background: Rectangle {
        radius: controlStyle.radius
        color: controlStyle.colorFor(controlStyle.normalSurface, root.designTokens.backgroundDeep)
        border.width: controlStyle.borderWidth
        border.color: root.activeFocus ? root.designTokens.accent : root.designTokens.border
    }
}
