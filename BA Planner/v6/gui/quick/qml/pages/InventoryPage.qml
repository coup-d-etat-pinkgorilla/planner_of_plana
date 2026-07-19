import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: page
    objectName: "inventoryPage"
    required property QtObject controller
    required property QtObject designTokens

    ColumnLayout {
        anchors.fill: parent
        spacing: designTokens.spacingMedium

        PlannerPanel {
            id: inventoryHeaderPanel
            objectName: "inventoryHeaderPanel"
            designTokens: page.designTokens
            componentKey: "inventory/header"
            diagonalEdge: "right"
            diagonalAngle: 80
            Layout.fillWidth: true
            Layout.preferredHeight: inventoryHeaderPanel.effectivePreferredHeight

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: inventoryHeaderPanel.effectiveContentSpacing

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: "인벤토리"
                        color: designTokens.text
                        font.pixelSize: designTokens.fontTitle
                        font.bold: true
                    }
                    Text {
                        text: controller ? controller.inventoryStatus : ""
                        color: designTokens.muted
                        font.pixelSize: designTokens.fontCaption
                    }
                }

                PlannerTextField {
                    id: searchField
                    designTokens: page.designTokens
                    Layout.preferredWidth: 360
                    placeholderText: "이름 또는 ID 검색"
                    font.pixelSize: designTokens.fontBody
                    onTextChanged: if (controller) controller.inventoryModel.query = text
                }

                PlannerComboBox {
                    id: categoryCombo
                    designTokens: page.designTokens
                    Layout.preferredWidth: 240
                    font.pixelSize: designTokens.fontBody
                    textRole: "label"
                    valueRole: "value"
                    model: [
                        { label: "전체", value: "all" },
                        { label: "장비", value: "equipment" },
                        { label: "오파츠", value: "ooparts" },
                        { label: "전술 교육 BD", value: "workbooks" },
                        { label: "활동 보고서", value: "activity_reports" },
                        { label: "강화석", value: "enhancement_stones" },
                        { label: "무기 부품", value: "weapon_parts" },
                        { label: "기술 노트", value: "skill_books" },
                        { label: "엘레프", value: "elephs" },
                        { label: "선물", value: "presents" },
                        { label: "재화", value: "resources" },
                        { label: "기타", value: "other" }
                    ]
                    onCurrentValueChanged: if (controller) controller.inventoryModel.category = currentValue
                }

                PlannerButton {
                    designTokens: page.designTokens
                    text: "새로고침"
                    font.pixelSize: designTokens.fontBody
                    enabled: controller !== null
                    onClicked: if (controller) controller.reloadInventory()
                }
            }
        }

        PlannerPanel {
            id: inventoryBodyPanel
            designTokens: page.designTokens
            componentKey: "inventory/body"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
                id: inventoryList
                objectName: "inventoryList"
                anchors.fill: parent
                anchors.margins: 14
                spacing: inventoryBodyPanel.effectiveContentSpacing
                clip: true
                reuseItems: true
                cacheBuffer: 240
                model: controller ? controller.inventoryModel : null
                ScrollBar.vertical: PlannerScrollBar {
                    objectName: "inventoryScrollBar"
                    designTokens: page.designTokens
                }

                delegate: PlannerDelegateSurface {
                    objectName: "inventoryDelegate"
                    required property int index
                    required property string itemKey
                    required property string itemId
                    required property string name
                    required property int quantity
                    required property string categoryLabel
                    required property string iconUrl
                    required property string lastSeenAt

                    width: inventoryList.width - 18
                    height: effectivePreferredHeight > 0 ? effectivePreferredHeight : 82
                    designTokens: page.designTokens
                    componentKey: "delegates/inventory-row"
                    alternate: index % 2 !== 0

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: parent.effectivePaddingLeft
                        anchors.topMargin: parent.effectivePaddingTop
                        anchors.rightMargin: parent.effectivePaddingRight
                        anchors.bottomMargin: parent.effectivePaddingBottom
                        spacing: 16

                        PlannerElementSurface {
                            objectName: "inventoryIconFrame"
                            designTokens: page.designTokens
                            componentKey: "elements/inventory-icon"
                            Layout.preferredWidth: effectivePreferredWidth > 0 ? effectivePreferredWidth : 58
                            Layout.preferredHeight: effectivePreferredHeight > 0 ? effectivePreferredHeight : 58
                            Image {
                                anchors.fill: parent
                                anchors.margins: 5
                                source: iconUrl
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                visible: status === Image.Ready
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "◇"
                                color: designTokens.muted
                                font.pixelSize: 26
                                visible: parent.children[0].status !== Image.Ready
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            Text {
                                Layout.fillWidth: true
                                text: name
                                color: designTokens.text
                                font.pixelSize: designTokens.fontBody
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: itemId || itemKey
                                color: designTokens.muted
                                font.pixelSize: designTokens.fontCaption
                                elide: Text.ElideRight
                            }
                        }

                        Text {
                            text: categoryLabel
                            color: designTokens.accentSoft
                            font.pixelSize: designTokens.fontCaption
                            Layout.preferredWidth: 190
                        }
                        Text {
                            text: Number(quantity).toLocaleString(Qt.locale(), "f", 0)
                            color: designTokens.text
                            font.pixelSize: designTokens.fontSection
                            font.bold: true
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: 180
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: inventoryList.count === 0
                    text: "조건에 맞는 인벤토리 항목이 없습니다."
                    color: designTokens.muted
                    font.pixelSize: designTokens.fontSection
                }
            }
        }
    }
}
