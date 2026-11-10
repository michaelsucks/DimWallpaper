pragma Singleton
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.Commons

// Shared state and the dim layers themselves. A singleton, so every bar's
// button drives the same layers and all monitors fade in lockstep.
//
// One full-screen, click-through layer per monitor sits on WlrLayer.Bottom:
// above the wallpaper (Background) and below every window.
Singleton {
  id: root

  property bool enabled: false

  // How dark the wallpaper gets at the center of the screen (edges go darker).
  readonly property real depth: 0.78

  // 0 = wallpaper at full brightness, 1 = fully dimmed.
  property real dim: 0

  function toggle() { enabled = !enabled }
  function setEnabled(value) { enabled = value === true }

  onEnabledChanged: {
    fadeIn.stop()
    fadeOut.stop()
    if (enabled) fadeIn.start()
    else fadeOut.start()
  }

  // Like house lights going down: moves on the first frame, then glides
  // slowly into the dark.
  NumberAnimation {
    id: fadeIn
    target: root; property: "dim"; to: 1
    duration: Style.duration(1600)
    easing.type: Easing.Bezier
    easing.bezierCurve: [0.25, 0.1, 0.25, 1.0, 1.0, 1.0]
  }

  NumberAnimation {
    id: fadeOut
    target: root; property: "dim"; to: 0
    duration: Style.duration(750)
    easing.type: Easing.OutCubic
  }

  Variants {
    model: Quickshell.screens

    // The layers stay mapped for the whole session. Mapping them on demand
    // makes Hyprland run its layer-open animation right as the fade starts.
    PanelWindow {
      id: win
      required property var modelData

      screen: modelData
      color: "transparent"

      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "dim-wallpaper"
      WlrLayershell.layer: WlrLayer.Bottom
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

      anchors {
        top: true
        bottom: true
        left: true
        right: true
      }

      // Empty input region: clicks fall straight through to the desktop.
      mask: Region {}

      // Opacity never reaches exactly 0. Qt skips drawing 0-opacity items, so
      // the first frame of the fade would pay for the initial render on every
      // monitor and stall. 0.001 is invisible.
      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: Math.max(root.dim * root.depth, 0.001)
      }

      // Vignette: edges fall off darker, pulling the eye to the center.
      Shape {
        anchors.fill: parent
        opacity: Math.max(root.dim, 0.001)
        // Drawn once into a texture, so the fade only changes opacity.
        layer.enabled: true

        ShapePath {
          strokeWidth: 0
          strokeColor: "transparent"
          fillGradient: RadialGradient {
            centerX: win.width / 2
            centerY: win.height / 2
            centerRadius: Math.sqrt(win.width * win.width + win.height * win.height) / 2
            focalX: win.width / 2
            focalY: win.height / 2
            GradientStop { position: 0.4; color: "transparent" }
            GradientStop { position: 1.0; color: "#a6000000" }
          }
          startX: 0; startY: 0
          PathLine { x: win.width; y: 0 }
          PathLine { x: win.width; y: win.height }
          PathLine { x: 0; y: win.height }
          PathLine { x: 0; y: 0 }
        }
      }
    }
  }
}
