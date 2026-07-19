import QtQuick
import QtQuick.Controls
import BAPlanner 1.0

Button {
    id: root
    required property QtObject designTokens
    property url imageSource
    property string caption: text
    property bool extendLeft: false
    property bool cutRight: true
    property bool triangleOnly: false
    property real weight: 1.0
    property real diagonalAngle: 80
    property real cornerRadius: 7
    readonly property real diagonalSlant: Math.min(
        Math.max(0, height - 2 * cornerRadius) / Math.max(0.01, Math.tan(diagonalAngle * Math.PI / 180)),
        width * 0.24,
        height * 0.48
    )
    text: caption
    padding: 0
    hoverEnabled: true
    Accessible.name: caption
    containmentMask: surface

    contentItem: Item { }
    background: HomeMenuSurface {
        id: surface
        anchors.fill: parent
        themePalette: root.designTokens.runtime
        imageSource: root.imageSource
        caption: root.caption
        extendLeft: root.extendLeft
        cutRight: root.cutRight
        triangleOnly: root.triangleOnly
        hovered: root.hovered
        pressed: root.down
        controlEnabled: root.enabled
        angle: root.diagonalAngle
        radius: root.cornerRadius
    }
}
