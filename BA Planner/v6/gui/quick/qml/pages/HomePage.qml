import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: page
    objectName: "homePage"
    required property QtObject controller
    required property QtObject designTokens
    property string workspaceMode: "none"
    signal navigateRequested(int pageIndex)

    readonly property url assetRoot: Qt.resolvedUrl("../../../../assets/ui/home_menu/")

    function showPrimaryWorkspace() {
        var nextMode = controller && controller.targetConnected ? "scan" : "connection"
        workspaceMode = workspaceMode === nextMode ? "none" : nextMode
        if (nextMode === "connection" && workspaceMode === "connection" && controller)
            controller.refreshWindows()
    }

    function menuBoundaryInset(rowItem) {
        var radius = menuPanel.effectiveRadius
        var sectionY = 20 + rowItem.y
        var progress = Math.max(0, Math.min(1, (sectionY - radius) / Math.max(1, menuPanel.height - 2 * radius)))
        return menuPanel.diagonalDepth * progress
    }

    Connections {
        target: controller
        function onTargetChanged() {
            if (!controller.targetConnected && page.workspaceMode === "scan")
                page.workspaceMode = "none"
        }
    }

    PlannerPanel {
        id: menuPanel
        objectName: "homeMenuSection"
        designTokens: page.designTokens
        componentKey: "home/menu"
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: effectivePreferredWidth > 0 ? effectivePreferredWidth : parent.width * 0.30
        protectDiagonalContent: false

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.topMargin: 20
            anchors.rightMargin: 18
            anchors.bottomMargin: 20
            spacing: menuPanel.effectiveContentSpacing

            HomeMenuRow {
                id: primaryRow
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 1
                Layout.rightMargin: page.menuBoundaryInset(primaryRow)
                HomeMenuButton {
                    objectName: "homePrimaryAction"
                    designTokens: page.designTokens
                    caption: controller && controller.targetConnected ? "스캔" : "싯딤의 상자와 연결"
                    imageSource: page.assetRoot + (controller && controller.targetConnected ? "scan.png" : "shittim.png")
                    onClicked: page.showPrimaryWorkspace()
                }
            }

            HomeMenuRow {
                id: workRow
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 1
                Layout.rightMargin: page.menuBoundaryInset(workRow)
                HomeMenuButton {
                    objectName: "homeStudentsAction"
                    designTokens: page.designTokens
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    caption: "학생부 확인"
                    imageSource: page.assetRoot + "students.png"
                    onClicked: page.navigateRequested(1)
                }
                HomeMenuButton {
                    objectName: "homePlanAction"
                    designTokens: page.designTokens
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    caption: "계획 설정"
                    imageSource: page.assetRoot + "plan.png"
                    onClicked: page.navigateRequested(2)
                }
                HomeMenuButton {
                    objectName: "homeInventoryAction"
                    designTokens: page.designTokens
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    caption: "인벤토리"
                    imageSource: page.assetRoot + "inventory.png"
                    onClicked: page.navigateRequested(3)
                }
            }

            HomeMenuRow {
                id: insightRow
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 1
                Layout.rightMargin: page.menuBoundaryInset(insightRow)
                HomeMenuButton {
                    objectName: "homeTacticalAction"
                    designTokens: page.designTokens
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    caption: "전술대항전"
                    imageSource: page.assetRoot + "pvp.png"
                    onClicked: page.navigateRequested(4)
                }
                HomeMenuButton {
                    objectName: "homeStatisticsAction"
                    designTokens: page.designTokens
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    caption: "통계"
                    imageSource: page.assetRoot + "statistics.png"
                    onClicked: page.navigateRequested(5)
                }
            }

            HomeMenuRow {
                id: settingsRow
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: 1
                Layout.rightMargin: page.menuBoundaryInset(settingsRow)
                HomeMenuButton {
                    objectName: "homeSettingsAction"
                    designTokens: page.designTokens
                    caption: "설정"
                    triangleOnly: true
                    onClicked: page.navigateRequested(6)
                }
            }
        }
    }

    PlannerPanel {
        id: connectionPanel
        objectName: "homeConnectionSection"
        designTokens: page.designTokens
        componentKey: "home/connection"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: effectivePreferredWidth > 0 ? effectivePreferredWidth : parent.width * 0.30
        visible: page.workspaceMode === "connection"

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 26
            anchors.topMargin: 26
            anchors.rightMargin: 26
            anchors.bottomMargin: 26
            spacing: connectionPanel.effectiveContentSpacing

            Text {
                Layout.fillWidth: true
                text: "싯딤의 상자와 연결"
                color: designTokens.text
                font.pixelSize: designTokens.fontSection
                font.bold: true
            }
            Text {
                Layout.fillWidth: true
                text: controller && controller.targetConnected
                    ? "연결됨 · " + controller.targetTitle
                    : "Blue Archive 창을 선택해 주세요."
                color: controller && controller.targetConnected ? designTokens.accentSoft : designTokens.muted
                font.pixelSize: designTokens.fontBody
                wrapMode: Text.WordWrap
            }

            ListView {
                id: windowList
                objectName: "homeWindowCandidateList"
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                clip: true
                model: controller ? controller.windowCandidates : []
                ScrollBar.vertical: PlannerScrollBar { designTokens: page.designTokens }

                delegate: PlannerDelegateSurface {
                    objectName: "homeWindowDelegate"
                    required property var modelData
                    width: windowList.width - 16
                    height: effectivePreferredHeight > 0 ? effectivePreferredHeight : 62
                    designTokens: page.designTokens
                    componentKey: "delegates/home-window-row"
                    selected: modelData.likelyBA
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: parent.effectivePaddingLeft
                        anchors.topMargin: parent.effectivePaddingTop
                        anchors.rightMargin: parent.effectivePaddingRight
                        anchors.bottomMargin: parent.effectivePaddingBottom
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: modelData.title
                                color: designTokens.text
                                font.pixelSize: designTokens.fontBody
                                elide: Text.ElideRight
                            }
                            Text { text: modelData.size; color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                        }
                        PlannerButton {
                            designTokens: page.designTokens
                            text: "연결"
                            font.pixelSize: designTokens.fontCaption
                            onClicked: if (controller) controller.connectWindow(modelData.hwnd, modelData.title)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                PlannerButton {
                    designTokens: page.designTokens
                    text: "새로고침"
                    onClicked: if (controller) controller.refreshWindows()
                }
                Item { Layout.fillWidth: true }
                PlannerButton {
                    designTokens: page.designTokens
                    text: "닫기"
                    onClicked: page.workspaceMode = "none"
                }
                PlannerButton {
                    designTokens: page.designTokens
                    variant: "danger"
                    visible: controller && controller.targetConnected
                    text: "연결 해제"
                    onClicked: if (controller) controller.disconnectWindow()
                }
            }
        }
    }

    PlannerPanel {
        id: scanPanel
        objectName: "homeScanSection"
        designTokens: page.designTokens
        componentKey: "home/scan"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: effectivePreferredWidth > 0 ? effectivePreferredWidth : parent.width * 0.30
        visible: page.workspaceMode === "scan"

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 26
            anchors.topMargin: 26
            anchors.rightMargin: 26
            anchors.bottomMargin: 26
            spacing: scanPanel.effectiveContentSpacing

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "스캔"
                    color: designTokens.text
                    font.pixelSize: designTokens.fontSection
                    font.bold: true
                }
                PlannerButton {
                    designTokens: page.designTokens
                    text: "닫기"
                    onClicked: page.workspaceMode = "none"
                }
            }
            Text {
                Layout.fillWidth: true
                text: controller ? controller.scanStatus : ""
                color: designTokens.muted
                font.pixelSize: designTokens.fontBody
                wrapMode: Text.WordWrap
            }
            PlannerProgressBar {
                objectName: "scanProgressBar"
                designTokens: page.designTokens
                Layout.fillWidth: true
                from: 0
                to: 100
                value: controller ? controller.scanProgress : 0
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 10
                columnSpacing: 10
                Repeater {
                    model: [
                        { label: "학생", mode: "students" },
                        { label: "단일", mode: "student_current" },
                        { label: "장비", mode: "equipment" },
                        { label: "전체 스캔", mode: "all" }
                    ]
                    delegate: PlannerButton {
                        required property var modelData
                        designTokens: page.designTokens
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        text: modelData.label
                        font.pixelSize: designTokens.fontBody
                        enabled: controller && controller.targetConnected && !controller.scanRunning
                        onClicked: if (controller) controller.startScan(modelData.mode)
                    }
                }
            }
            PlannerComboBox {
                id: itemFilter
                designTokens: page.designTokens
                Layout.fillWidth: true
                model: [
                    { label: "아이템 전체", value: "all" },
                    { label: "기술 노트", value: "tech_notes" },
                    { label: "전술 교육 BD", value: "tactical_bd" },
                    { label: "오파츠", value: "ooparts" },
                    { label: "엘레프", value: "student_elephs" },
                    { label: "선물", value: "presents" },
                    { label: "활동 보고서", value: "activity_reports" }
                ]
                textRole: "label"
                valueRole: "value"
            }
            PlannerButton {
                designTokens: page.designTokens
                Layout.fillWidth: true
                text: "선택 아이템 스캔"
                enabled: controller && controller.targetConnected && !controller.scanRunning
                onClicked: if (controller) controller.startItemScan(itemFilter.currentValue)
            }
            PlannerButton {
                designTokens: page.designTokens
                variant: "danger"
                Layout.fillWidth: true
                visible: controller && controller.scanRunning
                text: "스캔 중지 요청"
                onClicked: if (controller) controller.stopScan()
            }
            Text {
                text: "스캔 로그"
                color: designTokens.text
                font.pixelSize: designTokens.fontBody
                font.bold: true
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                PlannerTextArea {
                    designTokens: page.designTokens
                    text: controller ? controller.scanLog : ""
                    readOnly: true
                    wrapMode: TextArea.Wrap
                    color: designTokens.text
                    font.pixelSize: designTokens.fontCaption
                }
            }
        }
    }
}
