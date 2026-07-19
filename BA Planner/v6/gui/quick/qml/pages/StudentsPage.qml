import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: page
    objectName: "studentsPage"
    required property QtObject controller
    required property QtObject designTokens
    DelegateStyle { id: studentCardStyle; designTokens: page.designTokens; componentKey: "delegates/student-card" }

    function optionIndex(options, value) {
        for (let index = 0; index < options.length; ++index) {
            if (options[index].value === value)
                return index
        }
        return 0
    }

    PlannerPopup {
        id: advancedFilters
        objectName: "advancedFiltersPopup"
        designTokens: page.designTokens
        anchors.centerIn: Overlay.overlay
        width: 1500
        height: 820
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        contentItem: ColumnLayout {
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "전체 학생 필터"; color: designTokens.text; font.pixelSize: designTokens.fontTitle; font.bold: true }
                PlannerButton { designTokens: page.designTokens; text: "모두 해제"; onClicked: controller.studentModel.clearFilters() }
                PlannerButton { designTokens: page.designTokens; text: "닫기"; onClicked: advancedFilters.close() }
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                GridLayout {
                    width: advancedFilters.availableWidth - 30
                    columns: 4
                    columnSpacing: 14
                    rowSpacing: 12
                    Repeater {
                        model: controller ? controller.studentModel.filterFields : []
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Text { text: modelData.label; color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                            PlannerComboBox {
                                designTokens: page.designTokens
                                Layout.fillWidth: true
                                property var options: controller ? (controller.studentModel.filterOptions[modelData.key] || []) : []
                                model: options
                                textRole: "label"
                                valueRole: "value"
                                currentIndex: optionIndex(options, controller ? (controller.studentModel.selectedFilterValues[modelData.key] || "") : "")
                                onActivated: controller.studentModel.setFilter(modelData.key, currentValue)
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: designTokens.spacingMedium

        PlannerPanel {
            id: studentsHeaderPanel
            objectName: "studentsHeaderPanel"
            designTokens: page.designTokens
            componentKey: "students/header"
            diagonalEdge: "right"
            diagonalAngle: 80
            Layout.fillWidth: true
            Layout.preferredHeight: studentsHeaderPanel.effectivePreferredHeight

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: studentsHeaderPanel.effectiveContentSpacing

                RowLayout {
                    Layout.fillWidth: true
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "학생"
                            color: designTokens.text
                            font.pixelSize: designTokens.fontTitle
                            font.bold: true
                        }
                        Text {
                            text: controller ? controller.studentStatus : ""
                            color: designTokens.muted
                            font.pixelSize: designTokens.fontCaption
                        }
                    }
                    PlannerTextField {
                        designTokens: page.designTokens
                        Layout.preferredWidth: 420
                        placeholderText: "이름, ID, 학교, 역할 검색"
                        font.pixelSize: designTokens.fontBody
                        onTextChanged: if (controller) controller.studentModel.query = text
                    }
                    PlannerCheckBox {
                        objectName: "ownedStudentsCheckBox"
                        designTokens: page.designTokens
                        text: "보유 학생만"
                        font.pixelSize: designTokens.fontBody
                        onCheckedChanged: if (controller) controller.studentModel.ownedOnly = checked
                    }
                    PlannerButton {
                        designTokens: page.designTokens
                        text: "새로고침"
                        font.pixelSize: designTokens.fontBody
                        enabled: controller !== null
                        onClicked: if (controller) controller.reloadStudents()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Repeater {
                        model: [
                            { key: "school", label: "학교" },
                            { key: "attack_type", label: "공격" },
                            { key: "defense_type", label: "방어" },
                            { key: "combat_class", label: "편성" },
                            { key: "role", label: "역할" },
                            { key: "position", label: "포지션" }
                        ]
                        PlannerComboBox {
                            designTokens: page.designTokens
                            required property var modelData
                            Layout.fillWidth: true
                            model: controller ? (controller.studentModel.filterOptions[modelData.key] || []) : []
                            textRole: "label"
                            valueRole: "value"
                            displayText: modelData.label + ": " + currentText
                            onActivated: if (controller) controller.studentModel.setFilter(modelData.key, currentValue)
                        }
                    }
                    PlannerButton {
                        designTokens: page.designTokens
                        text: controller && controller.studentModel.activeFilterCount > 0
                              ? "필터 해제 (" + controller.studentModel.activeFilterCount + ")" : "필터 없음"
                        enabled: controller && controller.studentModel.activeFilterCount > 0
                        onClicked: if (controller) controller.studentModel.clearFilters()
                    }
                    PlannerButton { designTokens: page.designTokens; text: "전체 필터…"; onClicked: advancedFilters.open() }
                }
            }
        }

        PlannerPanel {
            id: studentsBodyPanel
            designTokens: page.designTokens
            componentKey: "students/body"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: studentsBodyPanel.effectiveContentSpacing

                GridView {
                    id: studentGrid
                    objectName: "studentGrid"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    cellWidth: Math.floor(width / (controller && controller.selectedStudentId ? 4 : 6))
                    cellHeight: studentCardStyle.preferredHeight > 0 ? studentCardStyle.preferredHeight : 226
                    clip: true
                    reuseItems: true
                    cacheBuffer: 300
                    model: controller ? controller.studentModel : null
                    ScrollBar.vertical: PlannerScrollBar { designTokens: page.designTokens }

                delegate: Item {
                    objectName: "studentDelegate"
                    required property int index
                    required property string studentId
                    required property string displayName
                    required property bool owned
                    required property int level
                    required property int star
                    required property string school
                    required property string attackType
                    required property string defenseType
                    required property string studentRole
                    required property string portraitUrl

                    width: studentGrid.cellWidth
                    height: studentGrid.cellHeight

                    PlannerDelegateSurface {
                        objectName: "studentDelegateSurface"
                        anchors.fill: parent
                        anchors.margins: 6
                        designTokens: page.designTokens
                        componentKey: "delegates/student-card"
                        selected: controller && controller.selectedStudentId === studentId
                        opacity: owned ? 1.0 : 0.58

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: parent.effectivePaddingLeft
                            anchors.topMargin: parent.effectivePaddingTop
                            anchors.rightMargin: parent.effectivePaddingRight
                            anchors.bottomMargin: parent.effectivePaddingBottom
                            spacing: 5

                            PlannerElementSurface {
                                objectName: "studentPortraitFrame"
                                designTokens: page.designTokens
                                componentKey: "elements/student-portrait"
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true
                                Image {
                                    anchors.fill: parent
                                    source: portraitUrl
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }
                                PlannerElementSurface {
                                    objectName: "studentStatusBadge"
                                    designTokens: page.designTokens
                                    componentKey: "elements/student-status-badge"
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: effectivePreferredHeight > 0 ? effectivePreferredHeight : 34
                                    Text {
                                        anchors.centerIn: parent
                                        text: owned ? "Lv." + level + "  ·  ★" + star : "미보유"
                                        color: designTokens.text
                                        font.pixelSize: designTokens.fontCaption
                                        font.bold: true
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: displayName
                                color: designTokens.text
                                font.pixelSize: designTokens.fontBody
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: [school, studentRole].filter(value => value.length > 0).join(" · ")
                                color: designTokens.muted
                                font.pixelSize: 12
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                            PlannerButton {
                                designTokens: page.designTokens
                                Layout.fillWidth: true
                                visible: owned
                                text: "플랜에 추가"
                                font.pixelSize: 12
                                onClicked: if (controller) controller.addPlanStudent(studentId)
                            }
                        }

                        TapHandler {
                            onTapped: if (controller) controller.selectedStudentId = studentId
                        }
                    }
                }
                }

                PlannerElementSurface {
                    objectName: "studentDetailPanel"
                    designTokens: page.designTokens
                    componentKey: "elements/student-detail-panel"
                    Layout.preferredWidth: controller && controller.selectedStudentId
                        ? (effectivePreferredWidth > 0 ? effectivePreferredWidth : 410) : 0
                    Layout.fillHeight: true
                    visible: width > 0
                    clip: true

                    ColumnLayout {
                        id: detailColumn
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10
                        property var detail: controller ? controller.selectedStudentDetail : ({})

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: detailColumn.detail.displayName || ""
                                color: designTokens.text
                                font.pixelSize: designTokens.fontSection
                                font.bold: true
                            }
                            PlannerButton { designTokens: page.designTokens; text: "닫기"; onClicked: controller.selectedStudentId = "" }
                        }
                        Image {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 250
                            source: detailColumn.detail.portraitUrl || ""
                            fillMode: Image.PreserveAspectCrop
                        }
                        Text { text: "Lv." + (detailColumn.detail.level || 0) + "  ·  ★" + (detailColumn.detail.star || 0); color: designTokens.accentSoft; font.pixelSize: designTokens.fontBody; font.bold: true }
                        Text { text: [detailColumn.detail.school, detailColumn.detail.combatClass, detailColumn.detail.role, detailColumn.detail.position].filter(v => v).join(" · "); color: designTokens.text; font.pixelSize: designTokens.fontBody; wrapMode: Text.Wrap }
                        Text { text: "공격/방어  " + (detailColumn.detail.attackType || "-") + " / " + (detailColumn.detail.defenseType || "-"); color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                        Text { text: "전용무기  ★" + (detailColumn.detail.weaponStar || 0) + "  Lv." + (detailColumn.detail.weaponLevel || 0) + "  " + (detailColumn.detail.weaponType || ""); color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                        Text { text: "스킬  " + (detailColumn.detail.skills || []).join(" / "); color: designTokens.text; font.pixelSize: designTokens.fontBody }
                        Text { text: "장비  " + (detailColumn.detail.equipment || []).join(" / "); color: designTokens.muted; font.pixelSize: designTokens.fontCaption; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: "기본 능력치  " + (detailColumn.detail.combatStats || []).join(" / "); color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                        Item { Layout.fillHeight: true }
                        PlannerButton {
                            designTokens: page.designTokens
                            Layout.fillWidth: true
                            visible: detailColumn.detail.owned || false
                            text: "플랜에 추가"
                            onClicked: controller.addPlanStudent(detailColumn.detail.studentId)
                        }
                    }
                }
            }
        }
    }
}
