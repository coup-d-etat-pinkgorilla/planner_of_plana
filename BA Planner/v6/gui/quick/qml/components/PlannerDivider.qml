import QtQuick

PlannerElementSurface {
    id: root
    componentKey: "elements/divider"
    implicitWidth: effectivePreferredWidth
    implicitHeight: effectivePreferredHeight > 0 ? effectivePreferredHeight : 1
}
