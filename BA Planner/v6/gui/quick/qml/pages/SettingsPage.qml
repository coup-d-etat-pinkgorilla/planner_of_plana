import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: page
    objectName: "settingsPage"
    required property QtObject controller
    required property QtObject designTokens

    RowLayout {
        anchors.fill: parent
        spacing: 18

        PlannerPanel {
            id: accountPanel
            designTokens: page.designTokens
            componentKey: "settings/account"
            Layout.preferredWidth: accountPanel.effectivePreferredWidth
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: accountPanel.effectiveContentSpacing
                Text { text: "계정 및 프로필"; color: designTokens.text; font.pixelSize: designTokens.fontTitle; font.bold: true }
                Text { text: "스캔 결과·플랜·전술 기록은 프로필별로 분리됩니다."; color: designTokens.muted; font.pixelSize: designTokens.fontBody; wrapMode: Text.Wrap }
                PlannerComboBox {
                    id: profileCombo
                    designTokens: page.designTokens
                    Layout.fillWidth: true
                    model: controller ? controller.profiles : []
                    currentIndex: controller ? Math.max(0, controller.profiles.indexOf(controller.profileName)) : 0
                }
                RowLayout {
                    Layout.fillWidth: true
                    PlannerButton {
                        designTokens: page.designTokens
                        Layout.fillWidth: true
                        text: "선택 프로필 적용"
                        enabled: controller && !controller.scanRunning && profileCombo.currentText.length > 0
                        onClicked: controller.switchProfile(profileCombo.currentText)
                    }
                    PlannerTextField { id: newProfileName; designTokens: page.designTokens; Layout.fillWidth: true; placeholderText: "새 프로필 이름" }
                    PlannerButton {
                        designTokens: page.designTokens
                        text: "새 프로필"
                        enabled: controller && !controller.scanRunning && newProfileName.text.trim().length > 0
                        onClicked: {
                            controller.switchProfile(newProfileName.text.trim())
                            newProfileName.clear()
                        }
                    }
                }
                PlannerDivider { designTokens: page.designTokens; Layout.fillWidth: true }
                Text { text: "현재 프로필  ·  " + (controller ? controller.profileName : ""); color: designTokens.accentSoft; font.pixelSize: designTokens.fontSection; font.bold: true }
                Text { text: controller && controller.scanRunning ? "스캔 중에는 프로필을 바꿀 수 없습니다." : "프로필을 바꾸면 학생·인벤토리·플랜 모델을 같은 수명 안에서 다시 로드합니다."; color: designTokens.muted; font.pixelSize: designTokens.fontBody; wrapMode: Text.Wrap; Layout.fillWidth: true }
                PlannerDivider { designTokens: page.designTokens; Layout.fillWidth: true }
                Text { text: "호환 도구"; color: designTokens.text; font.pixelSize: designTokens.fontSection; font.bold: true }
                Text { text: "Excel 전술 기록 가져오기와 기존 QWidget 스냅샷 등 고급 호환 기능을 별도 창에서 엽니다."; color: designTokens.muted; font.pixelSize: designTokens.fontCaption; wrapMode: Text.Wrap; Layout.fillWidth: true }
                PlannerButton { designTokens: page.designTokens; Layout.fillWidth: true; text: "레거시 Viewer 열기"; onClicked: controller.launchLegacyViewer() }
                Item { Layout.fillHeight: true }
            }
        }

        PlannerPanel {
            id: windowPanel
            designTokens: page.designTokens
            componentKey: "settings/window"
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: windowPanel.effectiveContentSpacing
                Text { text: "창 연결"; color: designTokens.text; font.pixelSize: designTokens.fontTitle; font.bold: true }
                Text { text: controller && controller.targetConnected ? "연결됨 · " + controller.targetTitle : "연결된 Blue Archive 창이 없습니다."; color: controller && controller.targetConnected ? designTokens.accentSoft : designTokens.muted; font.pixelSize: designTokens.fontBody; wrapMode: Text.Wrap }
                PlannerButton { designTokens: page.designTokens; text: "창 목록 새로고침"; onClicked: if (controller) controller.refreshWindows() }
                Text { text: "창 선택과 스캔 실행은 홈 화면에서 처리합니다."; color: designTokens.muted; font.pixelSize: designTokens.fontBody }
                Item { Layout.fillHeight: true }
            }
        }
    }
}
