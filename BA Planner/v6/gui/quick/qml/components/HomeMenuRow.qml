import QtQuick

Item {
    id: root
    default property alias contentData: host.data
    property real seamGap: 10
    property real diagonalAngle: 80
    property real cornerRadius: 7

    function menuButtons() {
        var result = []
        for (var index = 0; index < host.children.length; ++index) {
            var child = host.children[index]
            if (child && child.weight !== undefined)
                result.push(child)
        }
        return result
    }

    function relayout() {
        var buttons = menuButtons()
        if (buttons.length === 0 || width <= 0 || height <= 0)
            return
        var radius = Math.min(cornerRadius, width / 2, height / 2)
        var slant = Math.min(
            Math.max(0, height - 2 * radius) / Math.max(0.01, Math.tan(diagonalAngle * Math.PI / 180)),
            width * 0.24,
            height * 0.48
        )
        var totalWidth = width + (buttons.length - 1) * (slant - seamGap)
        var totalWeight = 0
        for (var weightIndex = 0; weightIndex < buttons.length; ++weightIndex)
            totalWeight += Math.max(0.01, buttons[weightIndex].weight)
        var left = 0
        for (var buttonIndex = 0; buttonIndex < buttons.length; ++buttonIndex) {
            var button = buttons[buttonIndex]
            var buttonWidth = totalWidth * Math.max(0.01, button.weight) / totalWeight
            var roundedLeft = Math.round(left)
            var right = buttonIndex === buttons.length - 1 ? width : Math.round(left + buttonWidth)
            button.x = roundedLeft
            button.y = 0
            button.width = Math.max(1, right - roundedLeft)
            button.height = height
            button.extendLeft = buttonIndex > 0
            button.cutRight = true
            button.diagonalAngle = diagonalAngle
            button.cornerRadius = cornerRadius
            left += buttonWidth - slant + seamGap
        }
    }

    onWidthChanged: relayout()
    onHeightChanged: relayout()
    Component.onCompleted: Qt.callLater(relayout)

    Item {
        id: host
        anchors.fill: parent
        onChildrenChanged: Qt.callLater(root.relayout)
    }
}
