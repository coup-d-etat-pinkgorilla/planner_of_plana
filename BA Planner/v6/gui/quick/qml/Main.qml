import QtQuick
import QtQuick.Controls
import BAPlanner 1.0
import "pages"
import "components"

Item {
    id: viewport
    width: 1280
    height: 720

    readonly property real canvasScale: Math.min(width / 1920, height / 1080)
    property int currentPage: 0

    DesignTokens {
        id: tokens
        objectName: "designTokens"
    }

    Rectangle {
        anchors.fill: parent
        color: tokens.background
    }

    Item {
        id: designCanvas
        objectName: "designCanvas"
        width: 1920
        height: 1080
        transformOrigin: Item.TopLeft
        scale: viewport.canvasScale
        x: (viewport.width - width * scale) / 2
        y: (viewport.height - height * scale) / 2

        TriangleTexture {
            objectName: "triangleTexture"
            anchors.fill: parent
            themePalette: tokens.runtime
        }

        Item {
            anchors.fill: parent
            anchors.margins: 24

            PlannerHeader {
                id: mainHeader
                objectName: "mainHeader"
                designTokens: tokens
                controller: appController
                currentPage: viewport.currentPage
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: mainHeader.resolvedHeight
                onNavigateRequested: function(pageIndex) {
                    viewport.currentPage = pageIndex
                }
            }

            Item {
                id: pageHost
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: mainHeader.bottom
                anchors.topMargin: viewport.currentPage === 0 ? 0 : 18
                anchors.bottom: parent.bottom

                Loader {
                    // Home and settings stay resident so those two navigation
                    // states can swap atomically without exposing an empty Loader.
                    anchors.fill: parent
                    active: true
                    asynchronous: false
                    visible: viewport.currentPage === 0
                    sourceComponent: HomePage {
                        controller: appController
                        designTokens: tokens
                        onNavigateRequested: function(pageIndex) {
                            viewport.currentPage = pageIndex
                        }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: viewport.currentPage === 1
                    sourceComponent: StudentsPage {
                        controller: appController
                        designTokens: tokens
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: viewport.currentPage === 2
                    sourceComponent: PlanPage {
                        controller: appController
                        designTokens: tokens
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: viewport.currentPage === 3
                    sourceComponent: InventoryPage {
                        controller: appController
                        designTokens: tokens
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: viewport.currentPage === 4
                    sourceComponent: TacticalPage {
                        controller: appController
                        designTokens: tokens
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: viewport.currentPage === 5
                    sourceComponent: StatisticsPage {
                        controller: appController
                        designTokens: tokens
                    }
                }

                Loader {
                    objectName: "settingsPageLoader"
                    anchors.fill: parent
                    active: true
                    asynchronous: false
                    visible: viewport.currentPage === 6
                    sourceComponent: SettingsPage {
                        controller: appController
                        designTokens: tokens
                    }
                }
            }
        }
    }
}
