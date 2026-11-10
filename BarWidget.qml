import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.michaelsucks.dim-wallpaper"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "io.github.michaelsucks.dim-wallpaper"

    function toggle(): void {
      DimState.toggle()
    }

    function enable(): void {
      DimState.setEnabled(true)
    }

    function disable(): void {
      DimState.setEnabled(false)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    active: DimState.enabled
    // Drama masks.
    text: "󰴂"
    tooltipText: DimState.enabled ? "Dim Wallpaper: On" : "Dim Wallpaper: Off"
    onPressed: DimState.toggle()
  }
}
