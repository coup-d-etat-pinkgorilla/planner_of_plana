import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import BAPlanner 1.0
import ".." as PlannerApp

Item {
    id: viewport
    width: 1280
    height: 720
    readonly property real canvasScale: Math.min(width / 1920, height / 1080)
    property var selectedEntry: ({})
    property bool previewControlActive: false
    property var previewTree: []
    property string selectedTreePath: ""
    property real previewTargetX: 0
    property real previewTargetY: 0
    property real previewTargetWidth: 1
    property real previewTargetHeight: 1
    property var studioPalette: studioController ? studioController.palette : ({})
    property var studioTypography: studioController ? studioController.typography : ({})
    property var previewPalette: ({
        "panel": studioPalette.panel || "#313b59",
        "panelAlt": studioPalette.panel_alt || "#2c3140",
        "panelRaised": studioPalette.panel || "#313b59",
        "surfaceSelected": studioPalette.accent || "#f266b3",
        "border": studioPalette.accent || "#f266b3",
        "shadow": "#151923"
    })

    function refreshSelectedEntry() {
        if (!studioController || !selectedEntry.entryId)
            return
        const rows = studioController.entries
        for (let index = 0; index < rows.length; ++index) {
            if (rows[index].entryId === selectedEntry.entryId) {
                selectedEntry = rows[index]
                return
            }
        }
    }

    function previewColor(token) {
        if (token === "accent" || token === "accentStrong") return studioPalette.accent || "#f266b3"
        if (token === "panelAlt") return studioPalette.panel_alt || "#2c3140"
        if (token === "backgroundDeep") return "#171923"
        if (token === "surfaceSelected") return studioPalette.accent || "#f266b3"
        if (token === "border") return studioPalette.soft || "#6f7890"
        if (token === "danger") return "#ef6a78"
        return studioPalette.panel || "#313b59"
    }

    function pageForEntry(entryId) {
        const key = String(entryId || "").replace(/^qml\//, "")
        if (key.startsWith("students/")) return 1
        if (key.startsWith("plan/")) return 2
        if (key.startsWith("inventory/")) return 3
        if (key.startsWith("tactical/")) return 4
        if (key.startsWith("statistics/")) return 5
        if (key.startsWith("settings/")) return 6
        return 0
    }

    function findVisual(item, predicate) {
        if (!item)
            return null
        if (predicate(item))
            return item
        const children = item.children || []
        for (let index = 0; index < children.length; ++index) {
            const found = findVisual(children[index], predicate)
            if (found)
                return found
        }
        return null
    }

    function objectType(item) {
        const raw = String(item || "Item")
        const open = raw.indexOf("(")
        const typeName = open >= 0 ? raw.substring(0, open) : raw
        const generated = typeName.indexOf("_QMLTYPE_")
        return generated >= 0 ? typeName.substring(0, generated) : typeName
    }

    function itemSegment(item, index) {
        const typeName = objectType(item)
        if (item.objectName && item.objectName.length > 0)
            return typeName + "#" + item.objectName
        if (item.componentKey !== undefined && String(item.componentKey).length > 0)
            return typeName + "[" + item.componentKey + "]"
        if (item.caption !== undefined && String(item.caption).length > 0)
            return typeName + "[caption=" + String(item.caption).split("/").join("_") + "]"
        if (item.text !== undefined && String(item.text).length > 0)
            return typeName + "[text=" + String(item.text).split("/").join("_") + "]"
        return typeName + "[" + index + "]"
    }

    function collectPreviewTree(target, rootPath) {
        const rows = []
        function visit(item, path, depth) {
            if (!item || rows.length >= 300 || depth > 12)
                return
            rows.push({
                "label": itemSegment(item, 0),
                "path": path,
                "depth": depth,
                "visible": item.visible === undefined ? true : item.visible
            })
            const children = item.children || []
            for (let index = 0; index < children.length; ++index) {
                const segment = itemSegment(children[index], index)
                visit(children[index], path + "/" + segment, depth + 1)
            }
        }
        visit(target, rootPath, 0)
        previewTree = rows
        selectedTreePath = rootPath
    }

    function refreshLiveSectionPreview() {
        if (selectedEntry.kind !== "qml_component") {
            previewTree = []
            selectedTreePath = ""
            return
        }
        livePlanner.currentPage = pageForEntry(selectedEntry.entryId)
        const homePage = findVisual(livePlanner, function(item) { return item.objectName === "homePage" })
        const componentKey = String(selectedEntry.entryId || "").replace(/^qml\//, "")
        if (homePage) {
            if (componentKey === "home/scan") homePage.workspaceMode = "scan"
            else if (componentKey === "home/connection") homePage.workspaceMode = "connection"
            else homePage.workspaceMode = "none"
        }
        const target = findVisual(livePlanner, function(item) {
            return item.componentKey !== undefined && String(item.componentKey) === componentKey
        })
        if (!target || target.width <= 0 || target.height <= 0) {
            previewRetry.restart()
            return
        }
        const origin = target.mapToItem(livePlanner, 0, 0)
        previewTargetX = origin.x
        previewTargetY = origin.y
        previewTargetWidth = target.width
        previewTargetHeight = target.height
        collectPreviewTree(target, selectedEntry.entryId)
    }

    onSelectedEntryChanged: {
        previewControlActive = false
        previewTree = []
        selectedTreePath = selectedEntry.entryId || ""
        livePreviewRefresh.restart()
    }

    Connections {
        target: studioController
        function onChanged() {
            viewport.refreshSelectedEntry()
            livePreviewRefresh.restart()
        }
    }

    Timer { id: livePreviewRefresh; interval: 80; onTriggered: viewport.refreshLiveSectionPreview() }
    Timer { id: previewRetry; interval: 80; onTriggered: viewport.refreshLiveSectionPreview() }

    Rectangle { anchors.fill: parent; color: "#151925" }

    Item {
        id: designCanvas
        objectName: "studioDesignCanvas"
        width: 1920; height: 1080
        scale: viewport.canvasScale
        transformOrigin: Item.TopLeft
        x: (viewport.width - width * scale) / 2
        y: (viewport.height - height * scale) / 2

        Rectangle { anchors.fill: parent; color: "#1d2230" }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 92; radius: 14
                color: studioPalette.panel_alt || "#2c3140"; border.color: "#56617b"
                RowLayout {
                    anchors.fill: parent; anchors.margins: 20; spacing: 12
                    Text { text: "UI COMPONENT STUDIO · QUICK"; color: studioPalette.text || "#f2f2f2"; font.pixelSize: 30; font.bold: true }
                    Text { Layout.fillWidth: true; text: studioController ? studioController.status : ""; color: studioPalette.soft || "#efe4f2"; font.pixelSize: 16; elide: Text.ElideRight }
                    Button { text: "명세 다시 읽기"; onClicked: studioController.reload() }
                    Button { text: "디자인 저장"; onClicked: studioController.save() }
                }
            }

            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 16
                Rectangle {
                    Layout.preferredWidth: 590; Layout.fillHeight: true; radius: 14
                    color: studioPalette.panel || "#313b59"; border.color: "#56617b"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 16
                        Text { text: "명세 항목 · " + (studioController ? studioController.entryCount : 0); color: studioPalette.text || "white"; font.pixelSize: 22; font.bold: true }
                        TextField { id: query; Layout.fillWidth: true; placeholderText: "selector 또는 위젯 종류 검색" }
                        ListView {
                            id: entryList
                            objectName: "studioEntryList"
                            Layout.fillWidth: true; Layout.fillHeight: true
                            model: studioController ? studioController.entries : []
                            clip: true; reuseItems: true; spacing: 5
                            ScrollBar.vertical: ScrollBar { }
                            delegate: Rectangle {
                                required property var modelData
                                visible: !query.text || (modelData.title + " " + modelData.entryId + " " + modelData.widgetType).toLowerCase().includes(query.text.toLowerCase())
                                width: entryList.width - 12
                                height: visible ? 72 : 0
                                radius: 9
                                color: viewport.selectedEntry.entryId === modelData.entryId ? "#5a3d62" : "#293147"
                                border.color: viewport.selectedEntry.entryId === modelData.entryId ? (studioPalette.accent || "#f266b3") : "#56617b"
                                Column {
                                    anchors.fill: parent; anchors.margins: 10; spacing: 3
                                    Text { width: parent.width; text: modelData.title; color: studioPalette.text || "white"; font.pixelSize: 16; font.bold: true; elide: Text.ElideRight }
                                    Text { width: parent.width; text: modelData.widgetType + " · " + modelData.shapeMode + (modelData.kind === "qml_component" ? (modelData.isOverride ? " · 저장 override" : " · 기본값") : ""); color: studioPalette.soft || "#ddd"; font.pixelSize: 12; elide: Text.ElideRight }
                                }
                                TapHandler { onTapped: viewport.selectedEntry = modelData }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true; radius: 14
                    color: "#252b3b"; border.color: "#56617b"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 22; spacing: 14
                        Text { text: viewport.selectedEntry.title || "항목을 선택하세요"; color: studioPalette.text || "white"; font.pixelSize: 26; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                        Text { text: viewport.selectedEntry.entryId || "실제 Planner QWidget 트리를 만들지 않고 JSON 명세만 미리 봅니다."; color: studioPalette.soft || "#ddd"; font.pixelSize: 14; wrapMode: Text.Wrap; Layout.fillWidth: true }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 360; radius: 12
                            color: "#777b84"; border.color: "#9da3b0"
                            Canvas {
                                id: shapePreview
                                visible: viewport.selectedEntry.kind !== "qml_component"
                                    && viewport.selectedEntry.kind !== "qml_control"
                                    && viewport.selectedEntry.kind !== "qml_overlay"
                                    && viewport.selectedEntry.kind !== "qml_delegate"
                                    && viewport.selectedEntry.kind !== "qml_element"
                                anchors.centerIn: parent; width: 760; height: 230
                                onPaint: {
                                    const ctx = getContext("2d")
                                    ctx.reset()
                                    ctx.clearRect(0, 0, width, height)
                                    const edge = viewport.selectedEntry.shapeEdge || "right"
                                    const angle = Math.max(5, Math.min(89.5, Number(viewport.selectedEntry.shapeAngle || 80)))
                                    const direction = viewport.selectedEntry.shapeDirection || "forward"
                                    const radians = angle * Math.PI / 180
                                    let depth = Number(viewport.selectedEntry.shapeDepth || 0) * 3
                                    if (viewport.selectedEntry.kind === "qml_component") {
                                        depth = edge === "left" || edge === "right"
                                            ? Math.max(0, height - 36) / Math.max(0.01, Math.tan(radians))
                                            : Math.max(0, width - 36) * Math.tan(radians)
                                    }
                                    depth = edge === "left" || edge === "right"
                                        ? Math.min(width / 3, depth) : Math.min(height / 3, depth)
                                    ctx.beginPath()
                                    if (edge === "none") {
                                        ctx.rect(0, 0, width, height)
                                    } else if (edge === "left") {
                                        ctx.moveTo(direction === "reverse" ? 0 : depth, 0)
                                        ctx.lineTo(width, 0); ctx.lineTo(width, height)
                                        ctx.lineTo(direction === "reverse" ? depth : 0, height)
                                    } else if (edge === "top") {
                                        ctx.moveTo(0, direction === "reverse" ? 0 : depth)
                                        ctx.lineTo(width, direction === "reverse" ? depth : 0)
                                        ctx.lineTo(width, height); ctx.lineTo(0, height)
                                    } else if (edge === "bottom") {
                                        ctx.moveTo(0, 0); ctx.lineTo(width, 0)
                                        ctx.lineTo(width, height - (direction === "reverse" ? 0 : depth))
                                        ctx.lineTo(0, height - (direction === "reverse" ? depth : 0))
                                    } else {
                                        ctx.moveTo(0, 0)
                                        ctx.lineTo(width - (direction === "reverse" ? depth : 0), 0)
                                        ctx.lineTo(width - (direction === "reverse" ? 0 : depth), height)
                                        ctx.lineTo(0, height)
                                    }
                                    ctx.closePath()
                                    const variant = viewport.selectedEntry.variant || "panel"
                                    ctx.fillStyle = variant === "alt" ? (studioPalette.panel_alt || "#2c3140")
                                        : variant === "selected" ? (studioPalette.accent || "#f266b3")
                                        : (studioPalette.panel || "#313b59")
                                    ctx.fill()
                                    ctx.strokeStyle = studioPalette.accent || "#f266b3"
                                    ctx.lineWidth = Math.max(0, Number(viewport.selectedEntry.borderWidth || 1) * 2)
                                    ctx.stroke()
                                }
                                Connections { target: viewport; function onSelectedEntryChanged() { shapePreview.requestPaint() } }
                                Connections { target: studioController; function onChanged() { shapePreview.requestPaint() } }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8
                                visible: viewport.selectedEntry.kind === "qml_component"

                                Rectangle {
                                    id: sectionPreviewViewport
                                    objectName: "studioSectionPreview"
                                    Layout.preferredWidth: Math.min(760, parent.width * 0.64)
                                    Layout.fillHeight: true
                                    color: "#1d2230"
                                    border.color: studioPalette.accent || "#f266b3"
                                    radius: 8
                                    clip: true
                                    readonly property real sectionScale: Math.min(
                                        width / Math.max(1, viewport.previewTargetWidth),
                                        height / Math.max(1, viewport.previewTargetHeight)
                                    )

                                    Item {
                                        id: liveScene
                                        width: 1920
                                        height: 1080
                                        transformOrigin: Item.TopLeft
                                        scale: sectionPreviewViewport.sectionScale
                                        x: (sectionPreviewViewport.width - viewport.previewTargetWidth * scale) / 2
                                            - viewport.previewTargetX * scale
                                        y: (sectionPreviewViewport.height - viewport.previewTargetHeight * scale) / 2
                                            - viewport.previewTargetY * scale

                                        PlannerApp.Main {
                                            id: livePlanner
                                            anchors.fill: parent
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.AllButtons
                                        hoverEnabled: true
                                    }

                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 6
                                        width: previewMetrics.implicitWidth + 14
                                        height: previewMetrics.implicitHeight + 8
                                        radius: 4
                                        color: "#b8171c2b"
                                        Text {
                                            id: previewMetrics
                                            anchors.centerIn: parent
                                            text: Math.round(viewport.previewTargetWidth) + "×" + Math.round(viewport.previewTargetHeight)
                                                + " · " + (viewport.previewTargetWidth / Math.max(1, viewport.previewTargetHeight)).toFixed(3) + ":1"
                                            color: studioPalette.text || "white"
                                            font.pixelSize: 12
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "#202637"
                                    border.color: "#56617b"
                                    radius: 8
                                    ColumnLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6
                                        RowLayout {
                                            Layout.fillWidth: true
                                            Text {
                                                Layout.fillWidth: true
                                                text: "섹션 객체 트리 · " + viewport.previewTree.length
                                                color: studioPalette.text || "white"
                                                font.pixelSize: 15
                                                font.bold: true
                                            }
                                            Button {
                                                objectName: "copySectionPathButton"
                                                text: "섹션 경로 복사"
                                                enabled: !!viewport.selectedEntry.entryId
                                                onClicked: studioController.copyText(viewport.selectedEntry.entryId || "")
                                            }
                                            Button {
                                                objectName: "openSectionPreviewButton"
                                                text: "미리보기 창"
                                                enabled: viewport.previewTree.length > 0
                                                onClicked: {
                                                    sectionPreviewWindow.show()
                                                    sectionPreviewWindow.raise()
                                                    sectionPreviewWindow.requestActivate()
                                                    sectionWindowRefresh.restart()
                                                }
                                            }
                                        }
                                        ListView {
                                            id: sectionTree
                                            objectName: "studioSectionTree"
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            model: viewport.previewTree
                                            clip: true
                                            spacing: 2
                                            ScrollBar.vertical: ScrollBar { }
                                            delegate: Rectangle {
                                                required property var modelData
                                                width: sectionTree.width - 10
                                                height: 30
                                                radius: 4
                                                color: viewport.selectedTreePath === modelData.path ? "#5a3d62" : "transparent"
                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.leftMargin: 6 + Number(modelData.depth || 0) * 14
                                                    anchors.rightMargin: 4
                                                    spacing: 4
                                                    Text {
                                                        Layout.fillWidth: true
                                                        text: modelData.label
                                                        color: modelData.visible ? (studioPalette.text || "white") : (studioPalette.soft || "#aaa")
                                                        font.pixelSize: 12
                                                        elide: Text.ElideMiddle
                                                    }
                                                    Button {
                                                        text: "복사"
                                                        implicitWidth: 54
                                                        implicitHeight: 26
                                                        onClicked: studioController.copyText(modelData.path)
                                                    }
                                                }
                                                TapHandler { onTapped: viewport.selectedTreePath = modelData.path }
                                                ToolTip.visible: treeHover.hovered
                                                ToolTip.text: modelData.path
                                                HoverHandler { id: treeHover }
                                            }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: viewport.selectedTreePath || "트리 아이템을 선택하세요."
                                            color: studioPalette.soft || "#ddd"
                                            font.pixelSize: 11
                                            elide: Text.ElideMiddle
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                id: controlPreview
                                anchors.centerIn: parent
                                width: viewport.selectedEntry.entryId === "qml/controls/scrollbar"
                                    ? Math.max(20, Number(viewport.selectedEntry.preferredWidth || 10) * 2)
                                    : Number(viewport.selectedEntry.preferredWidth || 0) > 0
                                        ? Math.max(48, Number(viewport.selectedEntry.preferredWidth) * 2) : 520
                                height: viewport.selectedEntry.entryId === "qml/controls/scrollbar"
                                    ? 220 : Math.max(24, Number(viewport.selectedEntry.preferredHeight || 48) * 2)
                                visible: viewport.selectedEntry.kind === "qml_control"
                                radius: Number(viewport.selectedEntry.radius || 0) * 2
                                color: viewport.previewColor(
                                    previewTap.pressed ? viewport.selectedEntry.pressedSurface
                                    : viewport.previewControlActive ? viewport.selectedEntry.activeSurface
                                    : previewHover.hovered ? viewport.selectedEntry.hoverSurface
                                    : viewport.selectedEntry.normalSurface
                                )
                                border.width: Number(viewport.selectedEntry.borderWidth || 0) * 2
                                border.color: studioPalette.accent || "#f266b3"
                                Rectangle {
                                    visible: viewport.selectedEntry.entryId === "qml/controls/progress"
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: parent.width * 0.62
                                    radius: parent.radius
                                    color: viewport.previewColor(viewport.selectedEntry.activeSurface)
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: viewport.selectedEntry.entryId !== "qml/controls/scrollbar"
                                        && viewport.selectedEntry.entryId !== "qml/controls/progress"
                                    text: viewport.selectedEntry.entryId === "qml/controls/checkbox"
                                        ? (viewport.previewControlActive ? "✓" : "")
                                        : previewTap.pressed ? "PRESSED" : viewport.previewControlActive ? "ACTIVE"
                                            : previewHover.hovered ? "HOVER" : "NORMAL"
                                    color: viewport.selectedEntry.entryId === "qml/controls/checkbox"
                                        ? "#171923" : studioPalette.text || "white"
                                    font.pixelSize: 22
                                    font.bold: true
                                }
                                HoverHandler { id: previewHover }
                                TapHandler { id: previewTap; onTapped: viewport.previewControlActive = !viewport.previewControlActive }
                            }
                            Rectangle {
                                anchors.fill: parent
                                visible: viewport.selectedEntry.kind === "qml_overlay"
                                color: viewport.previewColor(viewport.selectedEntry.scrimSurface)
                                opacity: Number(viewport.selectedEntry.scrimOpacityPercent || 0) / 100
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                visible: viewport.selectedEntry.kind === "qml_overlay"
                                width: viewport.selectedEntry.entryId === "qml/overlays/dropdown" ? 520 : 900
                                height: viewport.selectedEntry.entryId === "qml/overlays/dropdown"
                                    ? Math.min(260, Number(viewport.selectedEntry.preferredHeight || 360)) : 330
                                radius: Number(viewport.selectedEntry.radius || 0) * 2
                                color: viewport.previewColor(viewport.selectedEntry.surface)
                                border.width: Number(viewport.selectedEntry.borderWidth || 0) * 2
                                border.color: viewport.previewColor(viewport.selectedEntry.borderSurface)
                                Text {
                                    anchors.centerIn: parent
                                    text: viewport.selectedEntry.entryId === "qml/overlays/dropdown"
                                        ? "DROPDOWN SURFACE" : "MODAL DIALOG SURFACE"
                                    color: studioPalette.text || "white"
                                    font.pixelSize: 22
                                    font.bold: true
                                }
                            }
                            Column {
                                anchors.centerIn: parent
                                visible: viewport.selectedEntry.kind === "qml_delegate"
                                spacing: 12
                                Repeater {
                                    model: [
                                        { label: "NORMAL", token: viewport.selectedEntry.normalSurface, border: viewport.selectedEntry.borderSurface, selected: false },
                                        { label: "ALTERNATE", token: viewport.selectedEntry.alternateSurface, border: viewport.selectedEntry.borderSurface, selected: false },
                                        { label: "SELECTED", token: viewport.selectedEntry.selectedSurface, border: viewport.selectedEntry.selectedBorderSurface, selected: true }
                                    ]
                                    Rectangle {
                                        required property var modelData
                                        width: 800
                                        height: 68
                                        radius: Number(viewport.selectedEntry.radius || 0) * 2
                                        color: viewport.previewColor(modelData.token)
                                        border.width: modelData.selected
                                            ? Math.max(3, Number(viewport.selectedEntry.borderWidth || 0)) * 2
                                            : Number(viewport.selectedEntry.borderWidth || 0) * 2
                                        border.color: viewport.previewColor(modelData.border)
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: studioPalette.text || "white"
                                            font.pixelSize: 20
                                            font.bold: true
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                visible: viewport.selectedEntry.kind === "qml_element"
                                width: {
                                    const key = viewport.selectedEntry.entryId || ""
                                    if (key === "qml/elements/student-status-badge" || key === "qml/elements/statistics-meter") return 620
                                    if (Number(viewport.selectedEntry.preferredWidth || 0) > 0) return Math.max(116, Number(viewport.selectedEntry.preferredWidth) * 2)
                                    return 300
                                }
                                height: {
                                    const key = viewport.selectedEntry.entryId || ""
                                    if (key === "qml/elements/student-status-badge") return Math.max(40, Number(viewport.selectedEntry.preferredHeight || 34) * 2)
                                    if (key === "qml/elements/statistics-meter") return Math.max(24, Number(viewport.selectedEntry.preferredHeight || 12) * 2)
                                    if (Number(viewport.selectedEntry.preferredHeight || 0) > 0) return Math.max(80, Number(viewport.selectedEntry.preferredHeight) * 2)
                                    return 240
                                }
                                radius: Number(viewport.selectedEntry.radius || 0) * 2
                                color: viewport.previewColor(viewport.selectedEntry.surface)
                                border.width: Number(viewport.selectedEntry.borderWidth || 0) * 2
                                border.color: viewport.previewColor(viewport.selectedEntry.borderSurface)
                                opacity: Number(viewport.selectedEntry.opacityPercent || 0) / 100
                                Text {
                                    anchors.centerIn: parent
                                    text: viewport.selectedEntry.entryId === "qml/elements/statistics-meter"
                                        ? "" : "ELEMENT SURFACE"
                                    color: studioPalette.text || "white"
                                    font.pixelSize: 20
                                    font.bold: true
                                }
                            }
                        }
                        GridLayout {
                            Layout.fillWidth: true; columns: 4; columnSpacing: 10; rowSpacing: 10
                            Repeater {
                                model: ["accent", "soft", "panel", "panel_alt", "text"]
                                ColumnLayout {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    Text { text: modelData; color: studioPalette.text || "white"; font.pixelSize: 12 }
                                    TextField {
                                        Layout.fillWidth: true
                                        text: studioPalette[modelData] || ""
                                        onEditingFinished: studioController.setPalette(modelData, text)
                                    }
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "타이포그래피"; color: studioPalette.text || "white"; font.bold: true }
                            Repeater {
                                model: [
                                    { key: "font_caption", label: "캡션" },
                                    { key: "font_body", label: "본문" },
                                    { key: "font_section", label: "섹션" },
                                    { key: "font_title", label: "제목" }
                                ]
                                RowLayout {
                                    required property var modelData
                                    Text { text: modelData.label; color: studioPalette.soft || "#ddd" }
                                    SpinBox {
                                        from: 8
                                        to: 72
                                        value: Number(studioTypography[modelData.key] || 14)
                                        onValueModified: studioController.setTypography(modelData.key, value)
                                    }
                                }
                            }
                        }
                        RowLayout {
                            visible: viewport.selectedEntry.kind === "component" || viewport.selectedEntry.kind === "gallery"
                            Layout.fillWidth: true
                            ComboBox { id: shapeMode; Layout.fillWidth: true; model: ["cut", "extend"]; currentIndex: viewport.selectedEntry.shapeMode === "extend" ? 1 : 0 }
                            ComboBox { id: shapeEdge; Layout.fillWidth: true; model: ["left", "right", "both"]; currentIndex: Math.max(0, model.indexOf(viewport.selectedEntry.shapeEdge || "right")) }
                            SpinBox { id: shapeAngle; Layout.fillWidth: true; from: 5; to: 175; value: Number(viewport.selectedEntry.shapeAngle || 80) }
                            SpinBox { id: shapeDepth; Layout.fillWidth: true; from: 0; to: 400; value: Number(viewport.selectedEntry.shapeDepth || 24) }
                            Button {
                                text: "형태 적용"
                                enabled: viewport.selectedEntry.kind === "component"
                                onClicked: studioController.setShape(viewport.selectedEntry.entryId, shapeMode.currentText, shapeEdge.currentText, shapeAngle.value, shapeDepth.value)
                            }
                        }
                        GridLayout {
                            visible: viewport.selectedEntry.kind === "qml_component"
                            Layout.fillWidth: true
                            columns: 6
                            columnSpacing: 10
                            Text { text: "절삭 변"; color: studioPalette.text || "white" }
                            ComboBox { id: qmlEdge; Layout.fillWidth: true; model: ["none", "left", "right", "top", "bottom"]; currentIndex: Math.max(0, model.indexOf(viewport.selectedEntry.shapeEdge || "none")) }
                            Text { text: "방향"; color: studioPalette.text || "white" }
                            ComboBox { id: qmlDirection; Layout.fillWidth: true; model: ["forward", "reverse"]; currentIndex: Math.max(0, model.indexOf(viewport.selectedEntry.shapeDirection || "forward")) }
                            Text { text: "각도"; color: studioPalette.text || "white" }
                            SpinBox { id: qmlAngle; Layout.fillWidth: true; from: 5; to: 89; value: Number(viewport.selectedEntry.shapeAngle || 80) }
                            Text { text: "그림자"; color: studioPalette.text || "white" }
                            SpinBox { id: qmlElevation; Layout.fillWidth: true; from: 0; to: 4; value: Number(viewport.selectedEntry.elevation || 0) }
                            Text { text: "안전 여백"; color: studioPalette.text || "white" }
                            SpinBox { id: qmlSafeMargin; Layout.fillWidth: true; from: 0; to: 200; value: Number(viewport.selectedEntry.contentSafeMargin || 0) }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "QML 형태 적용"
                                onClicked: studioController.setQuickShape(
                                    viewport.selectedEntry.entryId,
                                    qmlEdge.currentText,
                                    qmlAngle.value,
                                    qmlDirection.currentText,
                                    qmlElevation.value,
                                    qmlSafeMargin.value
                                )
                            }
                            Button {
                                text: "기본값 복원"
                                enabled: viewport.selectedEntry.isOverride || false
                                onClicked: studioController.resetQuickComponent(viewport.selectedEntry.entryId)
                            }
                        }
                        RowLayout {
                            visible: viewport.selectedEntry.kind === "qml_component"
                            Layout.fillWidth: true
                            Text { text: "선호 너비"; color: studioPalette.text || "white" }
                            SpinBox { id: qmlPreferredWidth; from: 0; to: 1920; value: Number(viewport.selectedEntry.preferredWidth || 0) }
                            Text { text: "선호 높이"; color: studioPalette.text || "white" }
                            SpinBox { id: qmlPreferredHeight; from: 0; to: 1080; value: Number(viewport.selectedEntry.preferredHeight || 0) }
                            Text { text: "가로 패딩"; color: studioPalette.text || "white" }
                            SpinBox { id: qmlPaddingHorizontal; from: 0; to: 120; value: Number(viewport.selectedEntry.paddingLeft || 0) }
                            Text { text: "세로 패딩"; color: studioPalette.text || "white" }
                            SpinBox { id: qmlPaddingVertical; from: 0; to: 120; value: Number(viewport.selectedEntry.paddingTop || 0) }
                            Button {
                                text: "레이아웃 적용"
                                onClicked: studioController.setQuickLayout(
                                    viewport.selectedEntry.entryId,
                                    qmlPreferredWidth.value,
                                    qmlPreferredHeight.value,
                                    qmlPaddingHorizontal.value,
                                    qmlPaddingVertical.value
                                )
                            }
                        }
                        GridLayout {
                            visible: viewport.selectedEntry.kind === "qml_control"
                            Layout.fillWidth: true
                            columns: 10
                            columnSpacing: 8
                            Text { text: "너비"; color: studioPalette.text || "white" }
                            SpinBox { id: controlWidth; from: 0; to: 120; value: Number(viewport.selectedEntry.preferredWidth || 0) }
                            Text { text: "높이"; color: studioPalette.text || "white" }
                            SpinBox { id: controlHeight; from: 0; to: 120; value: Number(viewport.selectedEntry.preferredHeight || 0) }
                            Text { text: "반지름"; color: studioPalette.text || "white" }
                            SpinBox { id: controlRadius; from: 0; to: 40; value: Number(viewport.selectedEntry.radius || 0) }
                            Text { text: "테두리"; color: studioPalette.text || "white" }
                            SpinBox { id: controlBorder; from: 0; to: 6; value: Number(viewport.selectedEntry.borderWidth || 0) }
                            Item { Layout.fillWidth: true }
                            Button {
                                text: "기본값 복원"
                                enabled: viewport.selectedEntry.isOverride || false
                                onClicked: studioController.resetQuickComponent(viewport.selectedEntry.entryId)
                            }
                            Repeater {
                                id: controlSurfaceRepeater
                                model: [
                                    { key: "normalSurface", label: "NORMAL" },
                                    { key: "hoverSurface", label: "HOVER" },
                                    { key: "activeSurface", label: "ACTIVE" },
                                    { key: "pressedSurface", label: "PRESSED" }
                                ]
                                ColumnLayout {
                                    required property var modelData
                                    property alias surfaceControl: surfaceCombo
                                    Layout.columnSpan: 2
                                    Text { text: modelData.label; color: studioPalette.soft || "#ddd" }
                                    ComboBox {
                                        id: surfaceCombo
                                        Layout.fillWidth: true
                                        model: ["backgroundDeep", "panel", "panelAlt", "panelRaised", "surfaceSelected", "accent", "accentStrong", "border", "danger"]
                                        currentIndex: Math.max(0, model.indexOf(viewport.selectedEntry[modelData.key] || "panel"))
                                    }
                                }
                            }
                            Button {
                                objectName: "controlStyleApplyButton"
                                Layout.columnSpan: 2
                                text: "컨트롤 스타일 적용"
                                onClicked: {
                                    studioController.setQuickControlStyle(
                                        viewport.selectedEntry.entryId,
                                        controlWidth.value,
                                        controlHeight.value,
                                        controlRadius.value,
                                        controlBorder.value,
                                        controlSurfaceRepeater.itemAt(0).surfaceControl.currentText,
                                        controlSurfaceRepeater.itemAt(1).surfaceControl.currentText,
                                        controlSurfaceRepeater.itemAt(2).surfaceControl.currentText,
                                        controlSurfaceRepeater.itemAt(3).surfaceControl.currentText
                                    )
                                }
                            }
                        }
                        GridLayout {
                            visible: viewport.selectedEntry.kind === "qml_overlay"
                            Layout.fillWidth: true
                            columns: 10
                            columnSpacing: 8
                            Text { text: "너비"; color: studioPalette.text || "white" }
                            SpinBox { id: overlayWidth; from: 0; to: 1920; value: Number(viewport.selectedEntry.preferredWidth || 0) }
                            Text { text: "높이"; color: studioPalette.text || "white" }
                            SpinBox { id: overlayHeight; from: 0; to: 1080; value: Number(viewport.selectedEntry.preferredHeight || 0) }
                            Text { text: "패딩"; color: studioPalette.text || "white" }
                            SpinBox { id: overlayPadding; from: 0; to: 120; value: Number(viewport.selectedEntry.padding || 0) }
                            Text { text: "반지름"; color: studioPalette.text || "white" }
                            SpinBox { id: overlayRadius; from: 0; to: 64; value: Number(viewport.selectedEntry.radius || 0) }
                            Text { text: "테두리"; color: studioPalette.text || "white" }
                            SpinBox { id: overlayBorder; from: 0; to: 6; value: Number(viewport.selectedEntry.borderWidth || 0) }
                            Repeater {
                                id: overlaySurfaceRepeater
                                model: [
                                    { key: "surface", label: "SURFACE" },
                                    { key: "borderSurface", label: "BORDER" },
                                    { key: "scrimSurface", label: "SCRIM" }
                                ]
                                ColumnLayout {
                                    required property var modelData
                                    property alias surfaceControl: overlaySurfaceCombo
                                    Layout.columnSpan: 2
                                    Text { text: modelData.label; color: studioPalette.soft || "#ddd" }
                                    ComboBox {
                                        id: overlaySurfaceCombo
                                        Layout.fillWidth: true
                                        model: ["backgroundDeep", "panel", "panelAlt", "panelRaised", "surfaceSelected", "accent", "accentStrong", "border", "danger"]
                                        currentIndex: Math.max(0, model.indexOf(viewport.selectedEntry[modelData.key] || "panelAlt"))
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.columnSpan: 2
                                Text { text: "SCRIM %"; color: studioPalette.soft || "#ddd" }
                                SpinBox { id: overlayScrimOpacity; from: 0; to: 100; value: Number(viewport.selectedEntry.scrimOpacityPercent || 0) }
                            }
                            Button {
                                objectName: "overlayStyleApplyButton"
                                Layout.columnSpan: 2
                                text: "오버레이 스타일 적용"
                                onClicked: studioController.setQuickOverlayStyle(
                                    viewport.selectedEntry.entryId,
                                    overlayWidth.value,
                                    overlayHeight.value,
                                    overlayPadding.value,
                                    overlayRadius.value,
                                    overlayBorder.value,
                                    overlaySurfaceRepeater.itemAt(0).surfaceControl.currentText,
                                    overlaySurfaceRepeater.itemAt(1).surfaceControl.currentText,
                                    overlaySurfaceRepeater.itemAt(2).surfaceControl.currentText,
                                    overlayScrimOpacity.value
                                )
                            }
                            Button {
                                Layout.columnSpan: 2
                                text: "기본값 복원"
                                enabled: viewport.selectedEntry.isOverride || false
                                onClicked: studioController.resetQuickComponent(viewport.selectedEntry.entryId)
                            }
                        }
                        GridLayout {
                            visible: viewport.selectedEntry.kind === "qml_delegate"
                            Layout.fillWidth: true
                            columns: 10
                            columnSpacing: 8
                            Text { text: "높이"; color: studioPalette.text || "white" }
                            SpinBox { id: delegateHeight; from: 32; to: 320; value: Number(viewport.selectedEntry.preferredHeight || 82) }
                            Text { text: "왼쪽"; color: studioPalette.text || "white" }
                            SpinBox { id: delegatePaddingLeft; from: 0; to: 120; value: Number(viewport.selectedEntry.paddingLeft || 0) }
                            Text { text: "위"; color: studioPalette.text || "white" }
                            SpinBox { id: delegatePaddingTop; from: 0; to: 120; value: Number(viewport.selectedEntry.paddingTop || 0) }
                            Text { text: "오른쪽"; color: studioPalette.text || "white" }
                            SpinBox { id: delegatePaddingRight; from: 0; to: 120; value: Number(viewport.selectedEntry.paddingRight || 0) }
                            Text { text: "아래"; color: studioPalette.text || "white" }
                            SpinBox { id: delegatePaddingBottom; from: 0; to: 120; value: Number(viewport.selectedEntry.paddingBottom || 0) }
                            Text { text: "반지름"; color: studioPalette.text || "white" }
                            SpinBox { id: delegateRadius; from: 0; to: 64; value: Number(viewport.selectedEntry.radius || 0) }
                            Text { text: "테두리"; color: studioPalette.text || "white" }
                            SpinBox { id: delegateBorder; from: 0; to: 6; value: Number(viewport.selectedEntry.borderWidth || 0) }
                            Repeater {
                                id: delegateSurfaceRepeater
                                model: [
                                    { key: "normalSurface", label: "NORMAL" },
                                    { key: "alternateSurface", label: "ALTERNATE" },
                                    { key: "selectedSurface", label: "SELECTED" },
                                    { key: "borderSurface", label: "BORDER" },
                                    { key: "selectedBorderSurface", label: "SELECTED BORDER" }
                                ]
                                ColumnLayout {
                                    required property var modelData
                                    property alias surfaceControl: delegateSurfaceCombo
                                    Layout.columnSpan: 2
                                    Text { text: modelData.label; color: studioPalette.soft || "#ddd" }
                                    ComboBox {
                                        id: delegateSurfaceCombo
                                        Layout.fillWidth: true
                                        model: ["backgroundDeep", "panel", "panelAlt", "panelRaised", "surfaceSelected", "accent", "accentStrong", "border", "danger"]
                                        currentIndex: Math.max(0, model.indexOf(viewport.selectedEntry[modelData.key] || "panel"))
                                    }
                                }
                            }
                            Button {
                                objectName: "delegateStyleApplyButton"
                                Layout.columnSpan: 2
                                text: "반복 표면 스타일 적용"
                                onClicked: studioController.setQuickDelegateStyle(
                                    viewport.selectedEntry.entryId,
                                    delegateHeight.value,
                                    delegatePaddingLeft.value,
                                    delegatePaddingTop.value,
                                    delegatePaddingRight.value,
                                    delegatePaddingBottom.value,
                                    delegateRadius.value,
                                    delegateBorder.value,
                                    delegateSurfaceRepeater.itemAt(0).surfaceControl.currentText,
                                    delegateSurfaceRepeater.itemAt(1).surfaceControl.currentText,
                                    delegateSurfaceRepeater.itemAt(2).surfaceControl.currentText,
                                    delegateSurfaceRepeater.itemAt(3).surfaceControl.currentText,
                                    delegateSurfaceRepeater.itemAt(4).surfaceControl.currentText
                                )
                            }
                            Button {
                                Layout.columnSpan: 2
                                text: "기본값 복원"
                                enabled: viewport.selectedEntry.isOverride || false
                                onClicked: studioController.resetQuickComponent(viewport.selectedEntry.entryId)
                            }
                        }
                        GridLayout {
                            visible: viewport.selectedEntry.kind === "qml_element"
                            Layout.fillWidth: true
                            columns: 10
                            columnSpacing: 8
                            Text { text: "너비"; color: studioPalette.text || "white" }
                            SpinBox { id: elementWidth; from: 0; to: 640; value: Number(viewport.selectedEntry.preferredWidth || 0) }
                            Text { text: "높이"; color: studioPalette.text || "white" }
                            SpinBox { id: elementHeight; from: 0; to: 640; value: Number(viewport.selectedEntry.preferredHeight || 0) }
                            Text { text: "반지름"; color: studioPalette.text || "white" }
                            SpinBox { id: elementRadius; from: 0; to: 64; value: Number(viewport.selectedEntry.radius || 0) }
                            Text { text: "테두리"; color: studioPalette.text || "white" }
                            SpinBox { id: elementBorder; from: 0; to: 6; value: Number(viewport.selectedEntry.borderWidth || 0) }
                            Text { text: "불투명도 %"; color: studioPalette.text || "white" }
                            SpinBox { id: elementOpacity; from: 0; to: 100; value: Number(viewport.selectedEntry.opacityPercent || 0) }
                            Repeater {
                                id: elementSurfaceRepeater
                                model: [
                                    { key: "surface", label: "SURFACE" },
                                    { key: "borderSurface", label: "BORDER" }
                                ]
                                ColumnLayout {
                                    required property var modelData
                                    property alias surfaceControl: elementSurfaceCombo
                                    Layout.columnSpan: 2
                                    Text { text: modelData.label; color: studioPalette.soft || "#ddd" }
                                    ComboBox {
                                        id: elementSurfaceCombo
                                        Layout.fillWidth: true
                                        model: ["backgroundDeep", "panel", "panelAlt", "panelRaised", "surfaceSelected", "accent", "accentStrong", "border", "danger"]
                                        currentIndex: Math.max(0, model.indexOf(viewport.selectedEntry[modelData.key] || "backgroundDeep"))
                                    }
                                }
                            }
                            Button {
                                objectName: "elementStyleApplyButton"
                                Layout.columnSpan: 2
                                text: "내부 요소 스타일 적용"
                                onClicked: studioController.setQuickElementStyle(
                                    viewport.selectedEntry.entryId,
                                    elementWidth.value,
                                    elementHeight.value,
                                    elementRadius.value,
                                    elementBorder.value,
                                    elementOpacity.value,
                                    elementSurfaceRepeater.itemAt(0).surfaceControl.currentText,
                                    elementSurfaceRepeater.itemAt(1).surfaceControl.currentText
                                )
                            }
                            Button {
                                Layout.columnSpan: 2
                                text: "기본값 복원"
                                enabled: viewport.selectedEntry.isOverride || false
                                onClicked: studioController.resetQuickComponent(viewport.selectedEntry.entryId)
                            }
                        }
                        RowLayout {
                            visible: viewport.selectedEntry.kind === "qml_component"
                            Layout.fillWidth: true
                            Text { text: "표면"; color: studioPalette.text || "white" }
                            ComboBox { id: qmlVariant; model: ["panel", "alt", "raised", "selected"]; currentIndex: Math.max(0, model.indexOf(viewport.selectedEntry.variant || "panel")) }
                            Text { text: "반지름"; color: studioPalette.text || "white" }
                            SpinBox { id: qmlRadius; from: 0; to: 64; value: Number(viewport.selectedEntry.radius || 0) }
                            Text { text: "테두리"; color: studioPalette.text || "white" }
                            SpinBox { id: qmlBorderWidth; from: 0; to: 6; value: Number(viewport.selectedEntry.borderWidth || 0) }
                            Text { text: "간격"; color: studioPalette.text || "white" }
                            SpinBox { id: qmlContentSpacing; from: 0; to: 64; value: Number(viewport.selectedEntry.contentSpacing || 0) }
                            Button {
                                text: "표면 적용"
                                onClicked: studioController.setQuickStyle(
                                    viewport.selectedEntry.entryId,
                                    qmlVariant.currentText,
                                    qmlRadius.value,
                                    qmlBorderWidth.value,
                                    qmlContentSpacing.value
                                )
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }

    Window {
        id: sectionPreviewWindow
        objectName: "studioSectionPreviewWindow"
        width: 1280
        height: 720
        minimumWidth: 960
        minimumHeight: 540
        visible: false
        title: "UCS 섹션 미리보기 · " + (viewport.selectedEntry.title || "선택 없음")
        color: "#151925"
        readonly property real canvasScale: Math.min(width / 1920, height / 1080)
        readonly property real sectionRatio: viewport.previewTargetWidth / Math.max(1, viewport.previewTargetHeight)

        Item {
            id: sectionWindowCanvas
            width: 1920
            height: 1080
            transformOrigin: Item.TopLeft
            scale: sectionPreviewWindow.canvasScale
            x: (sectionPreviewWindow.width - width * scale) / 2
            y: (sectionPreviewWindow.height - height * scale) / 2

            Rectangle { anchors.fill: parent; color: "#1d2230" }

            Item {
                id: actualSectionClip
                objectName: "studioActualSectionClip"
                x: viewport.previewTargetX
                y: viewport.previewTargetY
                width: viewport.previewTargetWidth
                height: viewport.previewTargetHeight
                clip: true

                PlannerApp.Main {
                    id: sectionWindowPlanner
                    width: 1920
                    height: 1080
                    x: -viewport.previewTargetX
                    y: -viewport.previewTargetY
                    currentPage: viewport.pageForEntry(viewport.selectedEntry.entryId)
                }
            }

            Rectangle {
                x: actualSectionClip.x
                y: actualSectionClip.y
                width: actualSectionClip.width
                height: actualSectionClip.height
                color: "transparent"
                border.width: 2
                border.color: studioPalette.accent || "#f266b3"
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: 18
                width: sectionWindowLabel.implicitWidth + 22
                height: sectionWindowLabel.implicitHeight + 12
                radius: 6
                color: "#d9171c2b"
                Text {
                    id: sectionWindowLabel
                    anchors.centerIn: parent
                    text: (viewport.selectedEntry.entryId || "") + " · "
                        + Math.round(viewport.previewTargetWidth) + "×" + Math.round(viewport.previewTargetHeight)
                        + " · " + sectionPreviewWindow.sectionRatio.toFixed(3) + ":1"
                    color: studioPalette.text || "white"
                    font.pixelSize: 16
                }
            }
        }

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        onVisibleChanged: if (visible) sectionWindowRefresh.restart()
    }

    Timer {
        id: sectionWindowRefresh
        interval: 80
        onTriggered: {
            sectionWindowPlanner.currentPage = viewport.pageForEntry(viewport.selectedEntry.entryId)
            const homePage = viewport.findVisual(sectionWindowPlanner, function(item) { return item.objectName === "homePage" })
            const key = String(viewport.selectedEntry.entryId || "").replace(/^qml\//, "")
            if (homePage) {
                if (key === "home/scan") homePage.workspaceMode = "scan"
                else if (key === "home/connection") homePage.workspaceMode = "connection"
                else homePage.workspaceMode = "none"
            }
        }
    }
}
