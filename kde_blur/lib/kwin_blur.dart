import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A rectangle (in window-local pixels) to mark as blurred.
class BlurRect {
  final int x;
  final int y;
  final int width;
  final int height;

  const BlurRect(this.x, this.y, this.width, this.height);

  Map<String, int> _toMap() => {'x': x, 'y': y, 'w': width, 'h': height};
}

// ─────────────────────────────────────────────────────────────────────────────
// Low-level API
// ─────────────────────────────────────────────────────────────────────────────

/// Controls the KDE KWin compositor "blur behind" effect on Linux.
///
/// The window must already be transparent for blur to be visible.
/// This plugin only sets the KWin hint; it does not change window opacity.
class KwinBlur {
  static const MethodChannel _channel = MethodChannel('kwin_blur');

  /// Enables KWin blur for the application window.
  ///
  /// If [region] is null or empty the whole window is blurred.
  /// Otherwise each [BlurRect] defines an area to blur.
  ///
  /// On Wayland coordinates are in **logical pixels**;
  /// on X11 they are in **physical pixels**.
  /// Use [blurRegionForRoundedRect] to build the region from a [BorderRadius].
  ///
  /// On Wayland the call requires KWin with the blur effect enabled.
  /// On X11 the property is set unconditionally; non-KDE WMs ignore it.
  /// On non-Linux platforms this throws [UnsupportedError].
  static Future<void> enable({List<BlurRect>? region}) async {
    _ensureLinux();
    final rects = (region ?? const <BlurRect>[])
        .map((r) => r._toMap())
        .toList();
    final result = await _channel.invokeMethod<String>('enable', rects);
    _check(result);
  }

  /// Disables KWin blur for the application window.
  static Future<void> disable() async {
    _ensureLinux();
    final result = await _channel.invokeMethod<String>('disable');
    _check(result);
  }

  static void _ensureLinux() {
    if (!Platform.isLinux) {
      throw UnsupportedError(
        'kwin_blur is only supported on Linux (X11 or Wayland with KWin).',
      );
    }
  }

  static void _check(String? result) {
    if (result != null && result.startsWith('error:')) {
      throw Exception('kwin_blur: $result');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Geometry helper
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a scanline-approximated rounded-rectangle blur region.
///
/// Each corner of [borderRadius] may have independent, optionally elliptical
/// radii — [BorderRadius.circular], [BorderRadius.only], or any other Flutter
/// constructor all work.
///
/// **Coordinate space**
/// - Wayland: pass **logical pixels** — do NOT multiply by `devicePixelRatio`.
/// - X11: pass **physical pixels** — multiply by `devicePixelRatio`.
///
/// Example (Wayland, read size from the Flutter view):
/// ```dart
/// final view = WidgetsBinding.instance.platformDispatcher.views.first;
/// final logical = view.physicalSize / view.devicePixelRatio;
/// final region = blurRegionForRoundedRect(
///   logical.width.round(),
///   logical.height.round(),
///   BorderRadius.circular(12),
/// );
/// await KwinBlur.enable(region: region);
/// ```
List<BlurRect> blurRegionForRoundedRect(
  int width,
  int height,
  BorderRadius borderRadius,
) {
  int clampX(double v) => v.round().clamp(0, width ~/ 2);
  int clampY(double v) => v.round().clamp(0, height ~/ 2);

  final tlRx = clampX(borderRadius.topLeft.x);
  final tlRy = clampY(borderRadius.topLeft.y);
  final trRx = clampX(borderRadius.topRight.x);
  final trRy = clampY(borderRadius.topRight.y);
  final blRx = clampX(borderRadius.bottomLeft.x);
  final blRy = clampY(borderRadius.bottomLeft.y);
  final brRx = clampX(borderRadius.bottomRight.x);
  final brRy = clampY(borderRadius.bottomRight.y);

  // Pixel-centre ellipse inset at scanline [dy] into a corner (rx × ry).
  int arcInset(int dy, int rx, int ry) {
    if (rx == 0 || ry == 0) return 0;
    final t = (ry - dy - 0.5) / ry;
    if (t <= 0.0) return 0;
    return rx - (rx * math.sqrt(1.0 - t * t)).floor();
  }

  final lefts = List<int>.filled(height, 0);
  final rights = List<int>.filled(height, width);

  for (int y = 0; y < height; y++) {
    if (y < tlRy) lefts[y] = math.max(lefts[y], arcInset(y, tlRx, tlRy));
    if (y < trRy)
      rights[y] = math.min(rights[y], width - arcInset(y, trRx, trRy));

    final yb = height - 1 - y;
    if (y >= height - blRy)
      lefts[y] = math.max(lefts[y], arcInset(yb, blRx, blRy));
    if (y >= height - brRy)
      rights[y] = math.min(rights[y], width - arcInset(yb, brRx, brRy));
  }

  final rects = <BlurRect>[];
  int startY = 0;
  while (startY < height) {
    int endY = startY + 1;
    while (endY < height &&
        lefts[endY] == lefts[startY] &&
        rights[endY] == rights[startY]) {
      endY++;
    }
    final l = lefts[startY];
    final r = rights[startY];
    if (r > l) rects.add(BlurRect(l, startY, r - l, endY - startY));
    startY = endY;
  }

  return rects;
}

// ─────────────────────────────────────────────────────────────────────────────
// Punch-hole painter (used internally when Blurred.color is set)
// ─────────────────────────────────────────────────────────────────────────────

/// Makes every pixel in this widget's bounds alpha=0, punching through any
/// opaque Flutter layer painted earlier on the same picture layer.
///
/// Technique: `saveLayer` with `BlendMode.src` on the restore paint replaces
/// the destination with the (empty, fully-transparent) source buffer.
/// The enclosing `canvas.save()` + `clipRect/clipRRect` confines the effect
/// to exactly this widget's area so the rest of the window is untouched.
class _PunchHole extends LeafRenderObjectWidget {
  const _PunchHole({this.borderRadius});
  final BorderRadius? borderRadius;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPunchHole(borderRadius: borderRadius);

  @override
  void updateRenderObject(BuildContext context, _RenderPunchHole renderObject) {
    renderObject.borderRadius = borderRadius;
  }
}

class _RenderPunchHole extends RenderBox {
  _RenderPunchHole({this._borderRadius});

  BorderRadius? _borderRadius;
  set borderRadius(BorderRadius? value) {
    if (_borderRadius == value) return;
    _borderRadius = value;
    markNeedsPaint();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final rect = offset & size;

    // clip first — without this, BlendMode.src on restore() would affect the
    // entire current clip region (the whole window).
    canvas.save();
    if (_borderRadius != null) {
      canvas.clipRRect(_borderRadius!.toRRect(rect));
    } else {
      canvas.clipRect(rect);
    }
    canvas.saveLayer(rect, Paint()..blendMode = BlendMode.src);
    // buffer stays (0,0,0,0) — BlendMode.src on restore punches the hole
    canvas.restore();
    canvas.restore();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget API
// ─────────────────────────────────────────────────────────────────────────────

/// Internal singleton that owns the complete set of active blur rectangles
/// contributed by all [Blurred] widgets in the window. It coalesces every
/// registration into a single [KwinBlur.enable] call so multiple [Blurred]
/// widgets can coexist without overwriting each other.
///
/// Direct calls to [KwinBlur.enable] / [KwinBlur.disable] while [Blurred]
/// widgets are mounted will override the managed region.
class _BlurManager {
  _BlurManager._();
  static final instance = _BlurManager._();

  // Keyed by state object identity — each mounted _BlurredState gets a slot.
  final Map<_BlurredState, List<BlurRect>> _regions = {};

  void update(_BlurredState owner, List<BlurRect> rects) {
    _regions[owner] = rects;
    _apply();
  }

  void remove(_BlurredState owner) {
    if (_regions.remove(owner) != null) _apply();
  }

  void _apply() {
    final all = _regions.values.expand((r) => r).toList();
    if (all.isEmpty) {
      KwinBlur.disable().catchError((_) {});
    } else {
      KwinBlur.enable(region: all).catchError((_) {});
    }
  }
}

/// Applies the KDE KWin background blur effect to the rectangle it occupies
/// in the window.
///
/// Each [Blurred] widget registers its own region with a shared [_BlurManager];
/// all active [Blurred] widgets are composited into a single [KwinBlur.enable]
/// call, so multiple widgets can coexist freely.
///
/// **Basic usage** (requires transparent [Scaffold]):
/// ```dart
/// Blurred(
///   borderRadius: BorderRadius.circular(16),
///   child: Container(
///     width: 320,
///     height: 120,
///     color: Colors.white12,
///     child: const Center(child: Text('Blurred panel')),
///   ),
/// )
/// ```
///
/// **With [color]** (works with an opaque [Scaffold] background):
/// ```dart
/// Blurred(
///   color: Colors.white.withOpacity(0.08),
///   borderRadius: BorderRadius.circular(16),
///   child: MyPanel(),
/// )
/// ```
///
/// **Notes**
/// - Only works on Linux with KWin. On other platforms the widget renders its
///   [child] normally with no side effects.
/// - Position is measured via [RenderBox.localToGlobal] after each layout.
///   The region does **not** update automatically when the widget scrolls
///   inside a [ScrollView] — re-mount or call [KwinBlur.enable] manually if
///   needed.
/// - Using [KwinBlur.enable] / [KwinBlur.disable] directly while [Blurred]
///   widgets are in the tree will override the managed region.
class Blurred extends StatefulWidget {
  const Blurred({
    super.key,
    required this.child,
    this.borderRadius,
    this.disabled = false,
    this.color,
    this.expand = EdgeInsets.zero,
  });

  final Widget child;

  /// Optional rounded corners. Accepts any [BorderRadius] value —
  /// [BorderRadius.circular], [BorderRadius.only], [BorderRadius.vertical], or
  /// elliptical radii via [Radius.elliptical].
  final BorderRadius? borderRadius;

  /// When true the widget removes itself from the blur region and renders
  /// [child] with no compositor effect. Toggling this at runtime is cheap —
  /// no rebuild of [child] is triggered.
  final bool disabled;

  /// When provided, punches a transparent hole through every Flutter layer
  /// beneath this widget (using [BlendMode.src]) so KWin blur is visible even
  /// when the [Scaffold] has an opaque background color. The [color] is then
  /// drawn as a tint on top of the transparent hole — use a semi-transparent
  /// value (e.g. `Colors.white.withOpacity(0.08)`) for a frosted-glass look.
  ///
  /// When null (default), no hole is punched. The app must ensure the window
  /// surface is transparent for blur to show (e.g. set
  /// `Scaffold(backgroundColor: Colors.transparent)`).
  ///
  /// **Limitation:** the punch only reaches the current Flutter picture layer.
  /// A [RepaintBoundary] above this widget confines the punch to that
  /// boundary's surface rather than the root window surface.
  final Color? color;

  /// Expands the KWin blur region beyond the widget's own bounds on each side.
  /// Useful when a shadow or glow visually extends past the widget's layout rect.
  final EdgeInsets expand;

  @override
  State<Blurred> createState() => _BlurredState();
}

class _BlurredState extends State<Blurred> with WidgetsBindingObserver {
  static final _manager = _BlurManager.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleUpdate();
  }

  @override
  void didUpdateWidget(Blurred old) {
    super.didUpdateWidget(old);
    if (widget.disabled && !old.disabled) {
      _manager.remove(this);
    } else {
      _scheduleUpdate();
    }
  }

  @override
  void didChangeMetrics() {
    // Window was resized — our position in window coords may have shifted.
    _scheduleUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _manager.remove(this);
    super.dispose();
  }

  void _scheduleUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateRegion();
    });
  }

  void _updateRegion() {
    if (widget.disabled) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    // localToGlobal gives the offset in Flutter logical pixels from the
    // top-left of the Flutter view — the coordinate space KWin expects on
    // Wayland (surface-local). On X11 multiply by devicePixelRatio.
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final m = widget.expand;
    final x = (offset.dx - m.left).round();
    final y = (offset.dy - m.top).round();
    final w = (size.width + m.left + m.right).round();
    final h = (size.height + m.top + m.bottom).round();

    if (w <= 0 || h <= 0) return;

    final List<BlurRect> rects;
    if (widget.borderRadius != null) {
      rects = blurRegionForRoundedRect(
        w,
        h,
        widget.borderRadius!,
      ).map((r) => BlurRect(r.x + x, r.y + y, r.width, r.height)).toList();
    } else {
      rects = [BlurRect(x, y, w, h)];
    }

    _manager.update(this, rects);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.color != null && !widget.disabled) {
      // StackFit.passthrough forwards the parent's constraints unchanged to the
      // non-positioned child, so Blurred behaves identically to returning the
      // child directly (tight Row/Column constraints are preserved).
      return Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: _PunchHole(borderRadius: widget.borderRadius)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: widget.borderRadius,
              ),
            ),
          ),
          widget.child,
        ],
      );
    }
    return widget.child;
  }
}
