import QtQuick
import QtQuick.Layouts

Item {
    id: root
    objectName: "compoundMainHeader"
    required property QtObject designTokens
    required property QtObject controller
    property int currentPage: 0
    signal navigateRequested(int pageIndex)

    function syncActiveConnector() {
        var activeTab = tabRepeater.itemAt(0)
        if (!activeTab)
            return
        var origin = activeTab.mapToItem(root, 0, 0)
        activeConnector.x = origin.x
        activeConnector.width = activeTab.width
    }

    readonly property var runtimeOverride: typeof quickTheme !== "undefined" && quickTheme
        ? (quickTheme.components["main/header"] || ({})) : ({})
    readonly property real effectivePreferredHeight: runtimeOverride.preferredHeight !== undefined
        ? Number(runtimeOverride.preferredHeight) : 62
    readonly property real effectiveHomeHeight: 226
    readonly property real resolvedHeight: currentPage === 0 ? effectiveHomeHeight : effectivePreferredHeight

    PlannerPanel {
        anchors.fill: parent
        designTokens: root.designTokens
        componentKey: "main/header"
        radius: 5
        elevation: 2
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 0

        RowLayout {
            id: tabRow
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: root.effectivePreferredHeight - 4
            Layout.minimumHeight: root.effectivePreferredHeight - 4
            Layout.maximumHeight: root.effectivePreferredHeight - 4
            spacing: 8

            Text {
                text: "BA PLANNER"
                color: designTokens.text
                font.pixelSize: designTokens.fontSection
                font.bold: true
                Layout.leftMargin: 14
                Layout.preferredWidth: 420
            }

            Repeater {
                id: tabRepeater
                model: [
                    { label: "홈", page: 0 },
                    { label: "학생부", page: 1 },
                    { label: "계획", page: 2 },
                    { label: "인벤토리", page: 3 },
                    { label: "전술대항전", page: 4 }
                ]
                delegate: PlannerButton {
                    required property var modelData
                    objectName: "mainNavButton"
                    designTokens: root.designTokens
                    text: modelData.label
                    active: root.currentPage === modelData.page
                    onClicked: root.navigateRequested(modelData.page)
                    font.pixelSize: designTokens.fontBody
                    implicitWidth: modelData.page === 4 ? 142 : 104
                    Layout.fillHeight: true
                }
            }

            Item { Layout.fillWidth: true }

            PlannerPanel {
                designTokens: root.designTokens
                componentKey: "main/profile"
                Layout.preferredWidth: 270
                Layout.fillHeight: true
                Layout.rightMargin: 14
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 20
                    text: "프로필 · " + (controller ? controller.profileName : "")
                    color: designTokens.text
                    font.pixelSize: designTokens.fontBody
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Item {
            id: homeHeaderShell
            objectName: "homeHeaderSection"
            Layout.fillWidth: true
            Layout.fillHeight: false
            Layout.preferredHeight: root.effectiveHomeHeight - root.effectivePreferredHeight
            Layout.minimumHeight: root.effectiveHomeHeight - root.effectivePreferredHeight
            Layout.maximumHeight: root.effectiveHomeHeight - root.effectivePreferredHeight
            visible: root.currentPage === 0

            PlannerPanel {
                id: activeRegion
                objectName: "homeHeaderActiveRegion"
                anchors.fill: parent
                designTokens: root.designTokens
                componentKey: "home/header-active"
                protectDiagonalContent: false

                PlannerPanel {
                    id: headerContent
                    objectName: "homeHeaderContent"
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    anchors.topMargin: 5
                    anchors.rightMargin: activeRegion.diagonalDepth + 5
                    anchors.bottomMargin: 5
                    designTokens: root.designTokens
                    componentKey: "home/header-content"
                    protectDiagonalContent: false

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.topMargin: 14
                        anchors.rightMargin: headerContent.diagonalDepth + 18
                        anchors.bottomMargin: 14
                        spacing: 18

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Text {
                                Layout.fillWidth: true
                                text: "안녕하세요 선생님. 기다리고 있었습니다"
                                color: designTokens.text
                                font.pixelSize: designTokens.fontTitle
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "현재 프로필 · " + (controller ? controller.profileName : "")
                                color: designTokens.accentStrong
                                font.pixelSize: designTokens.fontBody
                                font.bold: true
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: controller && controller.targetConnected
                                    ? "싯딤의 상자 연결 완료 · " + controller.targetTitle
                                    : "Blue Archive 창 연결을 기다리고 있습니다."
                                color: designTokens.muted
                                font.pixelSize: designTokens.fontCaption
                                elide: Text.ElideRight
                            }
                        }

                        PlannerElementSurface {
                            designTokens: root.designTokens
                            componentKey: "elements/home-header-portrait"
                            Layout.preferredWidth: effectivePreferredWidth > 0 ? effectivePreferredWidth : 188
                            Layout.fillHeight: true
                            Image {
                                anchors.fill: parent
                                anchors.margins: 4
                                source: controller ? controller.headerPortraitUrl : ""
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                            }
                        }
                    }
                }
            }
        }
    }

    PlannerPanel {
        id: activeConnector
        objectName: "homeHeaderActiveConnector"
        visible: root.currentPage === 0
        designTokens: root.designTokens
        componentKey: "home/header-connector"
        x: 0
        y: root.effectivePreferredHeight - 7
        width: 1
        height: 12
        radius: 0
        elevation: 0
        borderWidth: 0
    }

    Timer {
        interval: 0
        running: true
        repeat: false
        onTriggered: root.syncActiveConnector()
    }
}
