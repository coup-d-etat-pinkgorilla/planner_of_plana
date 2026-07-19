import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../components"

Item {
    id: page
    objectName: "tacticalPage"
    required property QtObject controller
    required property QtObject designTokens

    FileDialog {
        id: screenshotDialog
        title: "전술대항전 결과 스크린샷 선택"
        nameFilters: ["이미지 (*.png *.jpg *.jpeg *.bmp *.webp)"]
        onAccepted: controller.analyzeTacticalScreenshot(selectedFile)
    }

    Connections {
        target: controller
        function onTacticalDraftChanged() {
            const draft = controller.tacticalDraft
            matchDate.text = draft.date || matchDate.text
            attackDeck.text = draft.attackDeck || ""
            defenseDeck.text = draft.defenseDeck || ""
            result.currentIndex = draft.result === "loss" ? 1 : 0
            mode.currentIndex = draft.mode === "defense" ? 1 : 0
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 16

        PlannerPanel {
            id: tacticalInputPanel
            designTokens: page.designTokens
            componentKey: "tactical/input"
            Layout.preferredWidth: tacticalInputPanel.effectivePreferredWidth
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: tacticalInputPanel.effectiveContentSpacing
                Text { text: "전술대항전 전적 입력"; color: designTokens.text; font.pixelSize: designTokens.fontTitle; font.bold: true }
                RowLayout {
                    PlannerTextField { id: matchDate; designTokens: page.designTokens; Layout.fillWidth: true; text: Qt.formatDate(new Date(), "yyyy-MM-dd"); placeholderText: "날짜" }
                    PlannerTextField { id: season; designTokens: page.designTokens; Layout.fillWidth: true; placeholderText: "시즌" }
                }
                PlannerTextField { id: opponent; designTokens: page.designTokens; Layout.fillWidth: true; placeholderText: "상대 이름" }
                RowLayout {
                    PlannerComboBox { id: result; designTokens: page.designTokens; Layout.fillWidth: true; model: [{label: "승리", value: "win"}, {label: "패배", value: "loss"}]; textRole: "label"; valueRole: "value" }
                    PlannerComboBox { id: mode; designTokens: page.designTokens; Layout.fillWidth: true; model: [{label: "공격 기록", value: "attack"}, {label: "방어 기록", value: "defense"}]; textRole: "label"; valueRole: "value" }
                }
                Text { text: "덱 형식: 스트라이커 4명 | 스페셜 2명"; color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                PlannerButton { designTokens: page.designTokens; Layout.fillWidth: true; text: "결과 스크린샷 분석"; onClicked: screenshotDialog.open() }
                PlannerTextArea { id: attackDeck; designTokens: page.designTokens; Layout.fillWidth: true; Layout.preferredHeight: 100; placeholderText: mode.currentValue === "defense" ? "상대 공격덱" : "내 공격덱"; wrapMode: TextEdit.Wrap }
                PlannerTextArea { id: defenseDeck; designTokens: page.designTokens; Layout.fillWidth: true; Layout.preferredHeight: 100; placeholderText: mode.currentValue === "defense" ? "내 방어덱" : "상대 방어덱"; wrapMode: TextEdit.Wrap }
                PlannerButton {
                    designTokens: page.designTokens
                    variant: "accent"
                    Layout.fillWidth: true
                    text: "전적 저장"
                    enabled: opponent.text.trim().length > 0
                    onClicked: {
                        controller.addTacticalMatch(matchDate.text, season.text, opponent.text, result.currentValue, mode.currentValue, attackDeck.text, defenseDeck.text)
                        opponent.clear(); attackDeck.clear(); defenseDeck.clear()
                    }
                }
                Text { Layout.fillWidth: true; text: controller ? controller.tacticalStatus : ""; color: designTokens.muted; font.pixelSize: designTokens.fontCaption; wrapMode: Text.Wrap }
                PlannerDivider { designTokens: page.designTokens; Layout.fillWidth: true; Layout.preferredHeight: effectivePreferredHeight }
                Text { text: "공격 족보"; color: designTokens.text; font.pixelSize: designTokens.fontSection; font.bold: true }
                PlannerTextField { id: jokboDefense; designTokens: page.designTokens; Layout.fillWidth: true; placeholderText: "검색할 상대 방어덱" }
                PlannerTextField { id: jokboAttack; designTokens: page.designTokens; Layout.fillWidth: true; placeholderText: "저장할 내 공격덱" }
                PlannerTextField { id: jokboNotes; designTokens: page.designTokens; Layout.fillWidth: true; placeholderText: "족보 메모" }
                RowLayout {
                    Layout.fillWidth: true
                    PlannerButton { designTokens: page.designTokens; Layout.fillWidth: true; text: "족보 검색"; onClicked: controller.searchTacticalJokbo(jokboDefense.text, "") }
                    PlannerButton { designTokens: page.designTokens; Layout.fillWidth: true; text: "수동 족보 저장"; onClicked: controller.addTacticalJokbo(jokboDefense.text, jokboAttack.text, jokboNotes.text) }
                }
                ListView {
                    id: jokboList
                    objectName: "tacticalJokboList"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 130
                    model: controller ? controller.tacticalJokboResults : []
                    clip: true; reuseItems: true; spacing: 5
                    ScrollBar.vertical: PlannerScrollBar { designTokens: page.designTokens }
                    delegate: PlannerDelegateSurface {
                        objectName: "tacticalJokboDelegate"
                        required property var modelData
                        width: jokboList.width - 12
                        height: effectivePreferredHeight > 0 ? effectivePreferredHeight : 78
                        designTokens: page.designTokens
                        componentKey: "delegates/tactical-jokbo-row"
                        Column {
                            anchors.fill: parent
                            anchors.leftMargin: parent.effectivePaddingLeft
                            anchors.topMargin: parent.effectivePaddingTop
                            anchors.rightMargin: parent.effectivePaddingRight
                            anchors.bottomMargin: parent.effectivePaddingBottom
                            spacing: 3
                            Text { width: parent.width; text: modelData.source + " · " + modelData.wins + "승 " + modelData.losses + "패 (" + modelData.winRate + "%)"; color: designTokens.accentSoft; font.pixelSize: designTokens.fontCaption; font.bold: true; elide: Text.ElideRight }
                            Text { width: parent.width; text: "ATK " + modelData.attackDeck; color: designTokens.text; font.pixelSize: 11; elide: Text.ElideRight }
                            Text { width: parent.width; text: "DEF " + modelData.defenseDeck; color: designTokens.muted; font.pixelSize: 11; elide: Text.ElideRight }
                        }
                        TapHandler { onTapped: { attackDeck.text = modelData.attackDeck; defenseDeck.text = modelData.defenseDeck } }
                    }
                }
            }
        }

        PlannerPanel {
            id: tacticalHistoryPanel
            designTokens: page.designTokens
            componentKey: "tactical/history"
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: tacticalHistoryPanel.effectiveContentSpacing
                RowLayout {
                    Layout.fillWidth: true
                    property var summary: controller ? controller.tacticalSummary : ({})
                    Text { text: "전적 " + (parent.summary.total || 0) + " · 승 " + (parent.summary.wins || 0) + " · 패 " + (parent.summary.losses || 0); color: designTokens.text; font.pixelSize: designTokens.fontSection; font.bold: true }
                    Item { Layout.fillWidth: true }
                    PlannerTextField { designTokens: page.designTokens; Layout.preferredWidth: 380; placeholderText: "상대·학생·메모 검색"; onAccepted: controller.searchTactical(text) }
                    PlannerButton { designTokens: page.designTokens; text: "새로고침"; onClicked: controller.reloadTactical() }
                }
                ListView {
                    id: matchList
                    objectName: "tacticalMatchList"
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: controller ? controller.tacticalModel : null
                    spacing: 7
                    clip: true
                    reuseItems: true
                    ScrollBar.vertical: PlannerScrollBar { designTokens: page.designTokens }
                    delegate: PlannerDelegateSurface {
                        objectName: "tacticalMatchDelegate"
                        required property string matchDate
                        required property string season
                        required property string opponent
                        required property string result
                        required property string mode
                        required property string attackDeck
                        required property string defenseDeck
                        required property string notes
                        width: matchList.width - 14
                        height: effectivePreferredHeight > 0 ? effectivePreferredHeight : 106
                        designTokens: page.designTokens
                        componentKey: "delegates/tactical-match-row"
                        border.color: result === "win" ? designTokens.success : designTokens.danger
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: parent.effectivePaddingLeft
                            anchors.topMargin: parent.effectivePaddingTop
                            anchors.rightMargin: parent.effectivePaddingRight
                            anchors.bottomMargin: parent.effectivePaddingBottom
                            spacing: 12
                            Text { text: result === "win" ? "승" : "패"; color: result === "win" ? designTokens.success : designTokens.danger; font.pixelSize: designTokens.fontSection; font.bold: true }
                            ColumnLayout {
                                Layout.preferredWidth: 230
                                Text { text: opponent; color: designTokens.text; font.pixelSize: designTokens.fontBody; font.bold: true }
                                Text { text: matchDate + (season ? " · " + season : "") + " · " + (mode === "defense" ? "방어" : "공격"); color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                Text { Layout.fillWidth: true; text: "ATK  " + attackDeck; color: designTokens.text; font.pixelSize: designTokens.fontCaption; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: "DEF  " + defenseDeck; color: designTokens.muted; font.pixelSize: designTokens.fontCaption; elide: Text.ElideRight }
                            }
                        }
                    }
                }
            }
        }
    }
}
