import QtQuick
import QtQuick.Controls

ComboBox {
    id: root
    required property QtObject designTokens

    ControlStyle { id: controlStyle; designTokens: root.designTokens; componentKey: "controls/combo" }
    implicitHeight: controlStyle.preferredHeight
    leftPadding: 14
    rightPadding: 42
    hoverEnabled: true

    contentItem: Text {
        leftPadding: root.leftPadding
        rightPadding: root.rightPadding
        text: root.displayText
        color: root.designTokens.text
        font: root.font
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    indicator: Item {
        x: root.width - width - 16
        y: (root.height - height) / 2
        width: 14
        height: 9
        Rectangle {
            x: 0
            y: 2
            width: 9
            height: 2
            radius: 1
            rotation: 42
            color: root.popup.visible ? root.designTokens.accent : root.designTokens.muted
        }
        Rectangle {
            x: 6
            y: 2
            width: 9
            height: 2
            radius: 1
            rotation: -42
            color: root.popup.visible ? root.designTokens.accent : root.designTokens.muted
        }
    }

    background: Rectangle {
        radius: controlStyle.radius
        color: controlStyle.colorFor(
            root.popup.visible ? controlStyle.activeSurface : root.hovered ? controlStyle.hoverSurface : controlStyle.normalSurface,
            root.designTokens.backgroundDeep
        )
        border.width: root.popup.visible ? Math.max(2, controlStyle.borderWidth) : controlStyle.borderWidth
        border.color: root.popup.visible ? root.designTokens.accent : root.designTokens.border
    }

    delegate: ItemDelegate {
        required property int index
        width: root.width - 8
        height: 44
        text: root.textAt(index)
        highlighted: root.highlightedIndex === index
        contentItem: Text {
            text: parent.text
            color: root.designTokens.text
            font: root.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: root.designTokens.radiusSmall
            color: parent.highlighted ? root.designTokens.surfaceSelected : "transparent"
        }
    }

    popup: PlannerPopup {
        objectName: "plannerComboPopup"
        designTokens: root.designTokens
        componentKey: "overlays/dropdown"
        y: root.height + 4
        width: root.width
        implicitHeight: Math.min(contentItem.implicitHeight + effectivePadding * 2,
            effectivePreferredHeight > 0 ? effectivePreferredHeight : 360)
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
            ScrollIndicator.vertical: ScrollIndicator { }
        }
    }
}
