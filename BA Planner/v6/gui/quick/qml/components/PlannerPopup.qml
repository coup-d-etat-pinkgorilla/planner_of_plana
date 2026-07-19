import QtQuick
import QtQuick.Controls

Popup {
    id: root
    required property QtObject designTokens
    property string componentKey: "overlays/dialog"

    OverlayStyle { id: overlayStyle; designTokens: root.designTokens; componentKey: root.componentKey }
    readonly property real effectivePreferredWidth: overlayStyle.preferredWidth
    readonly property real effectivePreferredHeight: overlayStyle.preferredHeight
    readonly property real effectivePadding: overlayStyle.padding
    readonly property real effectiveRadius: overlayStyle.radius
    readonly property real effectiveBorderWidth: overlayStyle.borderWidth
    readonly property string effectiveSurface: overlayStyle.surface
    readonly property string effectiveBorderSurface: overlayStyle.borderSurface
    readonly property string effectiveScrimSurface: overlayStyle.scrimSurface
    readonly property real effectiveScrimOpacity: overlayStyle.scrimOpacity

    padding: effectivePadding
    background: Rectangle {
        radius: root.effectiveRadius
        color: overlayStyle.colorFor(root.effectiveSurface, root.designTokens.panelAlt)
        border.width: root.effectiveBorderWidth
        border.color: overlayStyle.colorFor(root.effectiveBorderSurface, root.designTokens.accent)
    }
    Overlay.modal: Rectangle {
        color: overlayStyle.colorFor(root.effectiveScrimSurface, root.designTokens.backgroundDeep)
        opacity: root.effectiveScrimOpacity
    }
}
