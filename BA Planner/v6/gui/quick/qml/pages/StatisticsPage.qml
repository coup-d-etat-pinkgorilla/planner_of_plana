import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: page
    objectName: "statisticsPage"
    required property QtObject controller
    required property QtObject designTokens
    property var stats: controller ? controller.studentStatistics : ({})

    ColumnLayout {
        anchors.fill: parent
        spacing: 16
        PlannerPanel {
            id: statisticsHeaderPanel
            objectName: "statisticsHeaderPanel"
            designTokens: page.designTokens
            componentKey: "statistics/header"
            diagonalEdge: "right"
            diagonalAngle: 80
            Layout.fillWidth: true
            Layout.preferredHeight: statisticsHeaderPanel.effectivePreferredHeight
            RowLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: statisticsHeaderPanel.effectiveContentSpacing
                Text { text: "학생 통계"; color: designTokens.text; font.pixelSize: designTokens.fontTitle; font.bold: true }
                Item { Layout.fillWidth: true }
                Repeater {
                    model: [
                        { label: "표시 학생", value: stats.total || 0 },
                        { label: "보유 학생", value: stats.owned || 0 },
                        { label: "평균 레벨", value: stats.averageLevel || 0 }
                    ]
                    PlannerElementSurface {
                        objectName: "statisticsSummaryCard"
                        required property var modelData
                        designTokens: page.designTokens
                        componentKey: "elements/statistics-summary-card"
                        Layout.preferredWidth: effectivePreferredWidth > 0 ? effectivePreferredWidth : 230
                        Layout.preferredHeight: effectivePreferredHeight > 0 ? effectivePreferredHeight : 90
                        Column {
                            anchors.centerIn: parent; spacing: 4
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.value; color: designTokens.accentSoft; font.pixelSize: designTokens.fontTitle; font.bold: true }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                        }
                    }
                }
            }
        }
        PlannerPanel {
            id: statisticsBodyPanel
            designTokens: page.designTokens
            componentKey: "statistics/body"
            Layout.fillWidth: true
            Layout.fillHeight: true
            ListView {
                id: statsList
                objectName: "statisticsList"
                anchors.fill: parent
                anchors.margins: 18
                model: stats.groups || []
                spacing: statisticsBodyPanel.effectiveContentSpacing
                clip: true
                reuseItems: true
                ScrollBar.vertical: PlannerScrollBar { designTokens: page.designTokens }
                delegate: PlannerDelegateSurface {
                    objectName: "statisticsDelegate"
                    required property var modelData
                    width: statsList.width - 14
                    height: effectivePreferredHeight > 0 ? effectivePreferredHeight : 58
                    designTokens: page.designTokens
                    componentKey: "delegates/statistics-row"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: parent.effectivePaddingLeft
                        anchors.topMargin: parent.effectivePaddingTop
                        anchors.rightMargin: parent.effectivePaddingRight
                        anchors.bottomMargin: parent.effectivePaddingBottom
                        Text { Layout.preferredWidth: 200; text: modelData.category; color: designTokens.muted; font.pixelSize: designTokens.fontCaption }
                        Text { Layout.fillWidth: true; text: modelData.label; color: designTokens.text; font.pixelSize: designTokens.fontBody }
                        PlannerElementSurface {
                            objectName: "statisticsMeter"
                            designTokens: page.designTokens
                            componentKey: "elements/statistics-meter"
                            Layout.preferredWidth: Math.max(8, Math.min(420, (modelData.count / Math.max(1, stats.total)) * 900))
                            Layout.preferredHeight: effectivePreferredHeight > 0 ? effectivePreferredHeight : 12
                        }
                        Text { Layout.preferredWidth: 70; text: modelData.count; color: designTokens.accentSoft; font.pixelSize: designTokens.fontBody; horizontalAlignment: Text.AlignRight }
                    }
                }
            }
        }
    }
}
