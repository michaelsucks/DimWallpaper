import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.michaelsucks.dim-wallpaper"

  property bool menuOpen: false

  // Like Omarchy's own indicators: hidden while off, revealed (dimmed) when
  // the pointer is on the bar, fully lit while the wallpaper is dimmed.
  readonly property bool barPeek: !!bar && bar.centerSectionRevealHeld === true && bar.centerHoverRevealSuppressed !== true
  readonly property bool shown: DimState.enabled || menuOpen || barPeek

  QtObject {
    id: revealer
    readonly property bool revealInactiveIndicators: root.barPeek || root.menuOpen
  }

  // Collapse to nothing while hidden so it leaves no gap in the bar.
  implicitWidth: root.vertical ? button.implicitWidth : (root.shown ? button.implicitWidth : 0)
  implicitHeight: root.vertical ? (root.shown ? button.implicitHeight : 0) : button.implicitHeight
  clip: true

  // PopupCard calls this when you click outside it.
  function close() {
    closeTimer.stop()
    menuOpen = false
  }

  // After you let go of the slider, the menu closes on its own; grabbing the
  // knob again in that moment keeps it open.
  Timer {
    id: closeTimer
    interval: 500
    onTriggered: root.menuOpen = false
  }

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

    function darkness(level: string): void {
      DimState.setLevel(level)
    }
  }

  BarIndicator {
    id: button
    anchors.left: parent.left
    anchors.top: parent.top
    width: implicitWidth
    height: parent.height
    bar: root.bar
    indicatorHost: revealer
    active: DimState.enabled
    fixedWidth: root.vertical ? -1 : Style.bar.iconSlot
    // Light bulb.
    activeText: "󰌵"
    inactiveText: "󰌵"
    activeTooltipText: root.menuOpen ? "" : "Dim Wallpaper"
    inactiveTooltipText: root.menuOpen ? "" : "Dim Wallpaper"
    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.menuOpen = !root.menuOpen
      else DimState.toggle()
    }
  }


  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.menuOpen
    contentWidth: popup.fittedContentWidth(Style.space(240))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.fill: parent
      spacing: Style.space(8)

      Item {
        width: parent.width
        implicitHeight: percentText.implicitHeight

        Text {
          anchors.left: parent.left
          anchors.baseline: percentText.baseline
          textFormat: Text.PlainText
          text: "Dim Wallpaper"
          color: root.bar ? Qt.darker(root.bar.foreground, 1.4) : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        Text {
          id: percentText
          anchors.right: parent.right
          textFormat: Text.PlainText
          text: Math.round(slider.liveValue) + "%"
          color: root.bar ? root.bar.foreground : Color.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }
      }

      PanelSlider {
        id: slider
        bar: root.bar
        width: parent.width
        minimum: DimState.minPercent
        maximum: DimState.maxPercent
        step: 1
        integer: true
        value: DimState.percent
        // Drag to preview live; let go to save it as the default and close.
        onMoved: function(v) {
          closeTimer.stop()
          DimState.adjusting = true
          DimState.setEnabled(true)
          DimState.setPercent(v, false)
        }
        onReleased: function(v) {
          DimState.setEnabled(true)
          DimState.setPercent(v, true)
          DimState.adjusting = false
          closeTimer.restart()
        }
      }
    }
  }
}
