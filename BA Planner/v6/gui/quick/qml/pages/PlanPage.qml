import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: page
    objectName: "planPage"
    required property QtObject controller
    required property QtObject designTokens

    PlannerPopup {
        id: goalEditor
        objectName: "goalEditorPopup"
        designTokens: page.designTokens
        anchors.centerIn: Overlay.overlay
        width: 1400
        height: 820
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        property var detail: ({})
        contentItem: ColumnLayout {
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: goalEditor.detail.displayName || "상세 목표"; color: designTokens.text; font.pixelSize: designTokens.fontTitle; font.bold: true }
                PlannerCheckBox {
                    designTokens: page.designTokens
                    text: "즐겨찾기"
                    checked: goalEditor.detail.favorite || false
                    onToggled: if (goalEditor.detail.studentId) controller.setPlanFavorite(goalEditor.detail.studentId, checked)
                }
                PlannerButton { designTokens: page.designTokens; text: "닫기"; onClicked: goalEditor.close() }
            }
            Text { text: "0은 현재 상태 유지 또는 목표 없음으로 계산됩니다."; color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
            GridLayout {
                Layout.fillWidth: true
                columns: 4
                columnSpacing: 18
                rowSpacing: 10
                Repeater {
                    model: [
                        { key: "target_level", label: "레벨", max: 90 },
                        { key: "target_star", label: "성급", max: 5 },
                        { key: "target_weapon_star", label: "전용무기 성급", max: 4 },
                        { key: "target_weapon_level", label: "전용무기 레벨", max: 60 },
                        { key: "target_ex_skill", label: "EX 스킬", max: 5 },
                        { key: "target_skill1", label: "기본 스킬", max: 10 },
                        { key: "target_skill2", label: "강화 스킬", max: 10 },
                        { key: "target_skill3", label: "서브 스킬", max: 10 },
                        { key: "target_equip1_tier", label: "장비 1 티어", max: 10 },
                        { key: "target_equip1_level", label: "장비 1 레벨", max: 70 },
                        { key: "target_equip2_tier", label: "장비 2 티어", max: 10 },
                        { key: "target_equip2_level", label: "장비 2 레벨", max: 70 },
                        { key: "target_equip3_tier", label: "장비 3 티어", max: 10 },
                        { key: "target_equip3_level", label: "장비 3 레벨", max: 70 },
                        { key: "target_equip4_tier", label: "애용품 티어", max: 2 },
                        { key: "target_stat_hp", label: "능력 개방 HP", max: 25 },
                        { key: "target_stat_atk", label: "능력 개방 ATK", max: 25 },
                        { key: "target_stat_heal", label: "능력 개방 HEAL", max: 25 }
                    ]
                    RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: modelData.label; color: designTokens.text; font.pixelSize: designTokens.fontCaption }
                        PlannerSpinBox {
                            designTokens: page.designTokens
                            from: 0; to: modelData.max
                            value: Number(goalEditor.detail[modelData.key] || 0)
                            onValueModified: if (goalEditor.detail.studentId) controller.setPlanTarget(goalEditor.detail.studentId, modelData.key, value)
                        }
                    }
                }
            }
            PlannerTextArea {
                id: goalNotes
                designTokens: page.designTokens
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: goalEditor.detail.notes || ""
                placeholderText: "계획 메모"
                wrapMode: TextEdit.Wrap
                onActiveFocusChanged: if (!activeFocus && goalEditor.detail.studentId) controller.setPlanNotes(goalEditor.detail.studentId, text)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: designTokens.spacingMedium

        PlannerPanel {
            id: planHeaderPanel
            objectName: "planHeaderPanel"
            designTokens: page.designTokens
            componentKey: "plan/header"
            diagonalEdge: "right"
            diagonalAngle: 80
            Layout.fillWidth: true
            Layout.preferredHeight: planHeaderPanel.effectivePreferredHeight

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: planHeaderPanel.effectiveContentSpacing
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "성장 플랜"; color: designTokens.text; font.pixelSize: designTokens.fontTitle; font.bold: true }
                    Text { Layout.fillWidth: true; text: controller ? controller.planStatus : ""; color: designTokens.muted; font.pixelSize: designTokens.fontBody }
                    PlannerButton { designTokens: page.designTokens; text: "다시 불러오기"; font.pixelSize: designTokens.fontBody; onClicked: if (controller) controller.reloadPlan() }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 28
                    property var summary: controller ? controller.planSummary : ({})
                    Text { text: "크레딧  " + Number(parent.summary.credits || 0).toLocaleString(Qt.locale(), "f", 0); color: designTokens.accentSoft; font.pixelSize: designTokens.fontBody; font.bold: true }
                    Text { text: "레벨 경험치  " + Number(parent.summary.levelExp || 0).toLocaleString(Qt.locale(), "f", 0); color: designTokens.text; font.pixelSize: designTokens.fontBody }
                    Text { text: "장비 경험치  " + Number(parent.summary.equipmentExp || 0).toLocaleString(Qt.locale(), "f", 0); color: designTokens.text; font.pixelSize: designTokens.fontBody }
                    Text { text: "전용무기 경험치  " + Number(parent.summary.weaponExp || 0).toLocaleString(Qt.locale(), "f", 0); color: designTokens.text; font.pixelSize: designTokens.fontBody }
                    Item { Layout.fillWidth: true }
                }
            }
        }

        PlannerPanel {
            id: planBodyPanel
            designTokens: page.designTokens
            componentKey: "plan/body"
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: planBodyPanel.effectiveContentSpacing

                ListView {
                    id: planList
                    objectName: "planList"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 8
                    clip: true
                    reuseItems: true
                    cacheBuffer: 260
                    model: controller ? controller.planModel : null
                    ScrollBar.vertical: PlannerScrollBar { designTokens: page.designTokens }

                    delegate: PlannerDelegateSurface {
                        objectName: "planDelegate"
                        required property string studentId
                        required property string displayName
                        required property string portraitUrl
                        required property int currentLevel
                        required property int currentStar
                        required property int targetLevel
                        required property int targetStar
                        required property int targetExSkill
                        required property int targetSkill1
                        required property int targetSkill2
                        required property int targetSkill3

                        width: planList.width - 18
                        height: effectivePreferredHeight > 0 ? effectivePreferredHeight : 112
                        designTokens: page.designTokens
                        componentKey: "delegates/plan-row"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: parent.effectivePaddingLeft
                            anchors.topMargin: parent.effectivePaddingTop
                            anchors.rightMargin: parent.effectivePaddingRight
                            anchors.bottomMargin: parent.effectivePaddingBottom
                            spacing: 12
                            PlannerElementSurface {
                                objectName: "planPortraitFrame"
                                designTokens: page.designTokens
                                componentKey: "elements/plan-portrait"
                                Layout.preferredWidth: effectivePreferredWidth > 0 ? effectivePreferredWidth : 82
                                Layout.fillHeight: true
                                clip: true
                                Image { anchors.fill: parent; source: portraitUrl; fillMode: Image.PreserveAspectCrop }
                            }
                            ColumnLayout {
                                Layout.preferredWidth: 190
                                Text { text: displayName; color: designTokens.text; font.pixelSize: designTokens.fontBody; font.bold: true }
                                Text { text: "현재 Lv." + currentLevel + " · ★" + currentStar; color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                            }
                            Text { text: "목표 Lv."; color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                            PlannerSpinBox { designTokens: page.designTokens; from: Math.max(1, currentLevel); to: 90; value: targetLevel; onValueModified: if (controller) controller.setPlanTarget(studentId, "target_level", value) }
                            Text { text: "★"; color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                            PlannerSpinBox { designTokens: page.designTokens; from: Math.max(1, currentStar); to: 5; value: targetStar; onValueModified: if (controller) controller.setPlanTarget(studentId, "target_star", value) }
                            Text {
                                Layout.fillWidth: true
                                text: "스킬 " + targetExSkill + " / " + targetSkill1 + " / " + targetSkill2 + " / " + targetSkill3
                                color: designTokens.accentSoft; font.pixelSize: designTokens.fontCaption; horizontalAlignment: Text.AlignHCenter
                            }
                            PlannerButton {
                                designTokens: page.designTokens
                                text: "상세"
                                onClicked: {
                                    goalEditor.detail = controller.planGoalDetail(studentId)
                                    goalEditor.open()
                                }
                            }
                            PlannerButton { designTokens: page.designTokens; variant: "danger"; text: "삭제"; onClicked: if (controller) controller.removePlanStudent(studentId) }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: planList.count === 0
                        text: "학생 화면에서 성장 계획에 추가할 수 있습니다."
                        color: designTokens.muted
                        font.pixelSize: designTokens.fontSection
                    }
                }

                PlannerElementSurface {
                    objectName: "planResourceSummary"
                    designTokens: page.designTokens
                    componentKey: "elements/plan-resource-summary"
                    Layout.preferredWidth: effectivePreferredWidth > 0 ? effectivePreferredWidth : 430
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        Text { text: "총 필요 재화"; color: designTokens.text; font.pixelSize: designTokens.fontSection; font.bold: true }
                        Text { text: "보유량 차감 전 총량"; color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                        ListView {
                            id: resourceList
                            objectName: "planResourceList"
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 5
                            clip: true
                            reuseItems: true
                            model: controller ? controller.planResourceModel : null
                            ScrollBar.vertical: PlannerScrollBar { designTokens: page.designTokens }
                            delegate: PlannerDelegateSurface {
                                objectName: "planResourceDelegate"
                                required property string category
                                required property string name
                                required property int quantity
                                width: resourceList.width - 12
                                height: effectivePreferredHeight > 0 ? effectivePreferredHeight : 58
                                designTokens: page.designTokens
                                componentKey: "delegates/plan-resource-row"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: parent.effectivePaddingLeft
                                    anchors.topMargin: parent.effectivePaddingTop
                                    anchors.rightMargin: parent.effectivePaddingRight
                                    anchors.bottomMargin: parent.effectivePaddingBottom
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 0
                                        Text { text: name; color: designTokens.text; font.pixelSize: designTokens.fontCaption; elide: Text.ElideRight; Layout.fillWidth: true }
                                        Text { text: category; color: designTokens.muted; font.pixelSize: 11 }
                                    }
                                    Text { text: Number(quantity).toLocaleString(Qt.locale(), "f", 0); color: designTokens.accentSoft; font.pixelSize: designTokens.fontBody; font.bold: true }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
