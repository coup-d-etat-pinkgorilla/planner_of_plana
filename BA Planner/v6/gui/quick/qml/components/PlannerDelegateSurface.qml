import QtQuick

Rectangle {
    id: root
    required property QtObject designTokens
    required property string componentKey
    property bool alternate: false
    property bool selected: false

    DelegateStyle { id: delegateStyle; designTokens: root.designTokens; componentKey: root.componentKey }
    readonly property real effectivePreferredHeight: delegateStyle.preferredHeight
    readonly property real effectivePaddingLeft: Number(delegateStyle.contentPadding[0] || 0)
    readonly property real effectivePaddingTop: Number(delegateStyle.contentPadding[1] || 0)
    readonly property real effectivePaddingRight: Number(delegateStyle.contentPadding[2] || 0)
    readonly property real effectivePaddingBottom: Number(delegateStyle.contentPadding[3] || 0)
    readonly property real effectiveRadius: delegateStyle.radius
    readonly property real effectiveBorderWidth: delegateStyle.borderWidth
    readonly property string effectiveNormalSurface: delegateStyle.normalSurface
    readonly property string effectiveAlternateSurface: delegateStyle.alternateSurface
    readonly property string effectiveSelectedSurface: delegateStyle.selectedSurface
    readonly property string effectiveBorderSurface: delegateStyle.borderSurface
    readonly property string effectiveSelectedBorderSurface: delegateStyle.selectedBorderSurface
    readonly property string effectiveSurface: selected ? effectiveSelectedSurface
        : alternate ? effectiveAlternateSurface : effectiveNormalSurface

    radius: effectiveRadius
    color: delegateStyle.colorFor(effectiveSurface, designTokens.panel)
    border.width: selected ? Math.max(3, effectiveBorderWidth) : effectiveBorderWidth
    border.color: delegateStyle.colorFor(
        selected ? effectiveSelectedBorderSurface : effectiveBorderSurface,
        selected ? designTokens.accent : designTokens.border
    )
}
