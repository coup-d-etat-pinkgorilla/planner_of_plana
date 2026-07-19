import QtQuick
import BAPlanner 1.0

Item {
    id: root
    required property QtObject designTokens
    default property alias contentData: contentHost.data
    property string componentKey: ""
    property string variant: "panel"
    property real radius: designTokens.radiusPanel
    property real borderWidth: 1
    property real contentSpacing: 0
    property string diagonalEdge: "none"
    property real diagonalAngle: 80
    property string diagonalDirection: "forward"
    property real contentSafeMargin: 8
    property real elevation: 3
    property bool protectDiagonalContent: true

    readonly property var runtimeOverride: componentKey.length > 0
        && typeof quickTheme !== "undefined" && quickTheme
        ? (quickTheme.components[componentKey] || ({})) : ({})
    readonly property string effectiveDiagonalEdge: runtimeOverride.diagonalEdge !== undefined
        ? runtimeOverride.diagonalEdge : diagonalEdge
    readonly property real effectiveDiagonalAngle: runtimeOverride.diagonalAngle !== undefined
        ? Number(runtimeOverride.diagonalAngle) : diagonalAngle
    readonly property string effectiveDiagonalDirection: runtimeOverride.diagonalDirection !== undefined
        ? runtimeOverride.diagonalDirection : diagonalDirection
    readonly property real effectiveElevation: runtimeOverride.elevation !== undefined
        ? Number(runtimeOverride.elevation) : elevation
    readonly property real effectiveContentSafeMargin: runtimeOverride.contentSafeMargin !== undefined
        ? Number(runtimeOverride.contentSafeMargin) : contentSafeMargin
    readonly property real effectivePreferredWidth: runtimeOverride.preferredWidth !== undefined
        ? Number(runtimeOverride.preferredWidth) : 0
    readonly property real effectivePreferredHeight: runtimeOverride.preferredHeight !== undefined
        ? Number(runtimeOverride.preferredHeight) : 0
    readonly property var effectiveContentPadding: runtimeOverride.contentPadding !== undefined
        ? runtimeOverride.contentPadding : [0, 0, 0, 0]
    readonly property string effectiveVariant: runtimeOverride.variant !== undefined
        ? runtimeOverride.variant : variant
    readonly property real effectiveRadius: runtimeOverride.radius !== undefined
        ? Number(runtimeOverride.radius) : radius
    readonly property real effectiveBorderWidth: runtimeOverride.borderWidth !== undefined
        ? Number(runtimeOverride.borderWidth) : borderWidth
    readonly property real effectiveContentSpacing: runtimeOverride.contentSpacing !== undefined
        ? Number(runtimeOverride.contentSpacing) : contentSpacing

    implicitWidth: effectivePreferredWidth > 0 ? effectivePreferredWidth : 0
    implicitHeight: effectivePreferredHeight > 0 ? effectivePreferredHeight : 0

    readonly property real diagonalDepth: effectiveDiagonalEdge === "none" ? 0
        : Math.min(
            effectiveDiagonalEdge === "left" || effectiveDiagonalEdge === "right" ? width - 2 * effectiveRadius : height - 2 * effectiveRadius,
            effectiveDiagonalEdge === "left" || effectiveDiagonalEdge === "right"
                ? Math.max(0, height - 2 * effectiveRadius) / Math.max(0.01, Math.tan(effectiveDiagonalAngle * Math.PI / 180))
                : Math.max(0, width - 2 * effectiveRadius) * Math.tan(effectiveDiagonalAngle * Math.PI / 180)
        )

    PlannerSurface {
        anchors.fill: parent
        themePalette: root.designTokens.runtime
        variant: root.effectiveVariant
        radius: root.effectiveRadius
        borderWidth: root.effectiveBorderWidth
        diagonalEdge: root.effectiveDiagonalEdge
        diagonalAngle: root.effectiveDiagonalAngle
        diagonalDirection: root.effectiveDiagonalDirection
        shadowDepth: root.effectiveElevation
    }

    Item {
        id: contentHost
        anchors.fill: parent
        anchors.leftMargin: root.effectiveElevation + Number(root.effectiveContentPadding[0] || 0) + (root.protectDiagonalContent && root.effectiveDiagonalEdge === "left" ? root.diagonalDepth + root.effectiveContentSafeMargin : 0)
        anchors.topMargin: Number(root.effectiveContentPadding[1] || 0) + (root.effectiveDiagonalEdge === "top" ? root.diagonalDepth + root.effectiveContentSafeMargin : 0)
        anchors.rightMargin: root.effectiveElevation + Number(root.effectiveContentPadding[2] || 0) + (root.protectDiagonalContent && root.effectiveDiagonalEdge === "right" ? root.diagonalDepth + root.effectiveContentSafeMargin : 0)
        anchors.bottomMargin: root.effectiveElevation + Number(root.effectiveContentPadding[3] || 0) + (root.effectiveDiagonalEdge === "bottom" ? root.diagonalDepth + root.effectiveContentSafeMargin : 0)
    }
}
