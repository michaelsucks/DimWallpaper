pragma Singleton
import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
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

  // Darkness, 10 to 100 percent: how dark the wallpaper gets at the center of
  // the screen (the vignette takes the edges darker). 100 is true black,
  // which switches OLED pixels fully off.
  readonly property int minPercent: 10
  readonly property int maxPercent: 100
  property int percent: 78

  // True while the slider is being dragged: the dim then follows the knob
  // directly instead of easing behind it.
  property bool adjusting: false

  // Animated, so other changes while dimmed glide instead of jumping.
  property real depth: percent / 100
  Behavior on depth {
    enabled: !root.adjusting
    NumberAnimation { duration: Style.duration(400); easing.type: Easing.OutCubic }
  }

  // 0 = wallpaper at full brightness, 1 = fully dimmed.
  property real dim: 0

  function toggle() { enabled = !enabled }
  function setEnabled(value) { enabled = value === true }

  function clampPercent(value) {
    var n = Math.round(Number(value))
    if (isNaN(n)) return -1
    return Math.max(minPercent, Math.min(maxPercent, n))
  }

  // Applies a darkness; save = true also makes it the default.
  function setPercent(value, save) {
    var n = clampPercent(value)
    if (n < 0) return
    percent = n
    if (save) levelStore.setText(n + "\n")
  }

  // Accepts a percentage, or the 1.0.x preset names.
  function parseLevel(value) {
    var named = { soft: 60, normal: 78, oled: 100 }
    var s = String(value).trim().replace(/%$/, "")
    return named[s] !== undefined ? named[s] : clampPercent(s)
  }

  function setLevel(value) {
    var n = parseLevel(value)
    if (n >= 0) setPercent(n, true)
  }

  // The chosen darkness survives shell restarts and reboots.
  FileView {
    id: levelStore
    path: Quickshell.env("HOME") + "/.local/state/dim-wallpaper-darkness"
    printErrors: false
    onLoaded: {
      var n = root.parseLevel(text())
      if (n >= 0) root.percent = n
    }
  }

  onEnabledChanged: fade.startTo(enabled ? 1 : 0)

  // The fade runs on its own clock instead of Qt's animation driver. Qt ticks
  // animations at one monitor's refresh rate, so on a mixed setup (say 165Hz
  // and 240Hz) the faster screen would repeat frames and judder. This clock
  // ticks faster than any common display and computes the value from real
  // elapsed time, so every monitor gets a fresh value on each of its own
  // refreshes, whatever its rate.
  QtObject {
    id: fade

    property real from: 0
    property real to: 0
    property real startedAt: 0
    property int duration: 0
    property bool rising: true

    function startTo(target) {
      from = root.dim
      to = target
      rising = target > from
      // Lights down: slow and theatrical. Lights up: quicker.
      var full = rising ? Style.duration(1600) : Style.duration(750)
      // A fade that starts part-way (toggled mid-fade) takes its share of
      // the full time, so the speed stays consistent.
      duration = Math.round(full * Math.abs(target - from))
      if (duration <= 0) {
        clock.stop()
        root.dim = target
        return
      }
      startedAt = Date.now()
      clock.restart()
    }

    function tick() {
      var t = Math.min(1, (Date.now() - startedAt) / duration)
      // Down: CSS "ease", moving from the very first frame then gliding to
      // a stop. Up: ease-out cubic.
      var eased = rising ? fade.cubicBezier(t, 0.25, 0.1, 0.25, 1.0) : 1 - Math.pow(1 - t, 3)
      root.dim = from + (to - from) * eased
      if (t >= 1) clock.stop()
    }

    // Standard cubic-bezier easing: find the curve parameter for x = t with
    // Newton's method (bisection as a fallback), then return its y.
    function cubicBezier(t, x1, y1, x2, y2) {
      function sample(a1, a2, s) {
        return ((1 - 3 * a2 + 3 * a1) * s + (3 * a2 - 6 * a1)) * s * s + 3 * a1 * s
      }
      function slope(a1, a2, s) {
        return 3 * (1 - 3 * a2 + 3 * a1) * s * s + 2 * (3 * a2 - 6 * a1) * s + 3 * a1
      }
      var s = t
      for (var i = 0; i < 8; i++) {
        var err = sample(x1, x2, s) - t
        if (Math.abs(err) < 1e-6) break
        var d = slope(x1, x2, s)
        if (Math.abs(d) < 1e-6) break
        s -= err / d
      }
      if (s < 0 || s > 1 || Math.abs(sample(x1, x2, s) - t) > 1e-4) {
        var lo = 0, hi = 1
        s = t
        for (var j = 0; j < 30; j++) {
          var x = sample(x1, x2, s)
          if (Math.abs(x - t) < 1e-6) break
          if (x < t) lo = s; else hi = s
          s = (lo + hi) / 2
        }
      }
      return sample(y1, y2, s)
    }
  }

  Timer {
    id: clock
    interval: 3
    repeat: true
    onTriggered: fade.tick()
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
