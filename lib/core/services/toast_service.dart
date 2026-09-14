import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Dynamic-Island-style in-app notification.
///
/// Idle state: a 14x14 circular dot near the top of the screen (the size of
/// a front camera cutout). On show, it expands *in place* into a dark pill
/// --- the top edge stays fixed, it grows outward/downward, it never drops
/// down or travels across the screen. On dismiss it contracts back into the
/// dot and disappears.
///
/// The pill sizes itself to the actual message: an invisible copy of the
/// real content (icon + text) is laid out off-screen first, its true
/// rendered size is read back, and *that* exact size drives the pill, so
/// there is no separate width calculation that can disagree with what
/// Flutter itself renders. Short text never wraps; long text wraps onto
/// more lines and the pill grows taller to fit them, never truncating.
///
/// Size and content-opacity are driven by two SEPARATE animations, and
/// sequenced deliberately: on the way in, the pill finishes expanding to
/// its full, correctly-measured size before the text fades in; on the way
/// out, the text fully fades out *before* the pill starts shrinking back
/// toward the dot. This guarantees the text is never visible while the
/// pill is at some in-between size too small to hold it on one line.
///
/// Same public API as the original toast_service.dart --- nothing else in the
/// app needs to change:
///   ToastService.show(context, message, isError: false)
///   ToastService.showSuccess(context, message)
///   ToastService.showError(context, message)
///   ToastService.showWarning(context, message)
///   ToastService.showInfo(context, message)

enum _ToastType { success, error, warning, info }

class ToastService {
  ToastService._();

  static OverlayEntry? _currentEntry;
  static _ToastIslandState? _currentState;

  // ---- Public API -----------------------------------------------------

  static void show(BuildContext context, String message,
      {bool isError = false}) {
    _showToast(
      context,
      message,
      isError ? _ToastType.error : _ToastType.success,
    );
  }

  static void showSuccess(BuildContext context, String message) {
    _showToast(context, message, _ToastType.success);
  }

  static void showError(BuildContext context, String message) {
    _showToast(context, message, _ToastType.error);
  }

  static void showWarning(BuildContext context, String message) {
    _showToast(context, message, _ToastType.warning);
  }

  static void showInfo(BuildContext context, String message) {
    _showToast(context, message, _ToastType.info);
  }

  // ---- Internals --------------------------------------------------------

  static void _showToast(
      BuildContext context, String message, _ToastType type) {
    // If a toast is already showing, retract it instantly then show the new one.
    _dismissCurrent(immediate: true);

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _ToastIsland(
        message: message,
        type: type,
        onStateCreated: (state) => _currentState = state,
        onDismissed: () {
          entry.remove();
          if (_currentEntry == entry) {
            _currentEntry = null;
            _currentState = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void _dismissCurrent({bool immediate = false}) {
    if (_currentState != null) {
      _currentState!.retract(immediate: immediate);
    } else {
      _currentEntry?.remove();
      _currentEntry = null;
    }
  }
}

class _ToastIsland extends StatefulWidget {
  final String message;
  final _ToastType type;
  final ValueChanged<_ToastIslandState> onStateCreated;
  final VoidCallback onDismissed;

  const _ToastIsland({
    required this.message,
    required this.type,
    required this.onStateCreated,
    required this.onDismissed,
  });

  @override
  State<_ToastIsland> createState() => _ToastIslandState();
}

class _ToastIslandState extends State<_ToastIsland>
    with TickerProviderStateMixin {
  // ---- Tuning knobs -----------------------------------------------------

  /// Idle dot diameter.
  static const double baseSize = 14;

  /// Expanded pill bounds --- it sizes itself to the message within these.
  static const double _minOpenWidth = 120;
  static const double _maxOpenWidth = 320;
  static const double _minOpenHeight = 44;

  static const double _horizontalPadding = 14;
  static const double _verticalPadding = 11;
  static const double _iconSize = 18;
  static const double _iconGap = 8;

  static const TextStyle _textStyle = TextStyle(
    color: Colors.white,
    fontSize: 13.5,
    fontWeight: FontWeight.w500,
    height: 1.25,
    decoration: TextDecoration.none,
  );

  /// Spring used for the expand-in.
  static final SpringDescription _entrySpring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 34,
  );

  /// How fast content fades in/out. Kept short and separate from the size
  /// animation on purpose --- see class doc.
  static const Duration _fadeDuration = Duration(milliseconds: 140);

  /// How fast the pill contracts back down into the dot, once the content
  /// has already fully faded out.
  static const Duration _retractDuration = Duration(milliseconds: 320);

  /// How long the toast stays open before auto-dismissing.
  static const Duration _visibleDuration = Duration(seconds: 3);

  // Size: 0 = idle dot, 1 = fully open pill. Driven by a real spring on the
  // way in; tweened back down on the way out.
  late final AnimationController _sizeController;

  // Content opacity: fully independent of size, so it can be sequenced
  // relative to it (fade in only once fully open; fade out completely
  // before the pill starts shrinking).
  late final AnimationController _fadeController;

  bool _dismissing = false;

  // The real, laid-out size of the content --- read back from the hidden
  // measurer widget after its first frame. Nothing is guessed or
  // recomputed separately, so the animated pill can never disagree with it.
  final GlobalKey _measureKey = GlobalKey();
  double _openWidth = _minOpenWidth;
  double _openHeight = _minOpenHeight;
  bool _measured = false;

  @override
  void initState() {
    super.initState();
    widget.onStateCreated(this);

    _sizeController = AnimationController(vsync: this, value: 0);
    _fadeController = AnimationController(
      vsync: this,
      duration: _fadeDuration,
      value: 0,
    );

    // Only start fading the content in once the pill has actually finished
    // expanding to its full (correctly measured) size.
    _sizeController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_dismissing) {
        _fadeController.forward();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());

    Future.delayed(_visibleDuration, () {
      if (mounted) retract();
    });
  }

  /// Reads the real rendered size of the hidden measurer (see build()) and
  /// uses it directly as the pill's target size, then kicks off the
  /// expand spring. If the first frame hasn't laid it out yet, retries on
  /// the next frame.
  void _measureAndStart() {
    if (!mounted) return;

    final renderBox =
        _measureKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndStart());
      return;
    }

    final size = renderBox.size;
    setState(() {
      // Add 2.0 to the exact measured width to prevent fractional 
      // pixel rounding from causing the visible text to wrap unexpectedly.
      _openWidth = (size.width + 2.0).clamp(_minOpenWidth, _maxOpenWidth);
      _openHeight = math.max(_minOpenHeight, size.height);
      _measured = true;
    });

    _sizeController.animateWith(SpringSimulation(_entrySpring, 0, 1, 0));
  }

  void retract({bool immediate = false}) {
    if (_dismissing) return;
    _dismissing = true;

    if (immediate) {
      widget.onDismissed();
      return;
    }
    _performRetract();
  }

  /// Fade the content out completely FIRST --- while the pill is still at
  /// full size --- then, only once it's invisible, shrink the pill back
  /// down into the dot. This ordering is what prevents the text from ever
  /// being visible while the pill is some in-between size too small to
  /// hold it on one line.
  Future<void> _performRetract() async {
    await _fadeController.animateTo(
      0,
      duration: _fadeDuration,
      curve: Curves.easeOut,
    );

    if (!mounted) return;

    await _sizeController.animateTo(
      0,
      duration: _retractDuration,
      curve: Curves.easeInCubic,
    );

    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _sizeController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ---- Type styling -------------------------------------------------

  Color get _accentColor {
    switch (widget.type) {
      case _ToastType.success:
        return const Color(0xFF34C759); // green
      case _ToastType.error:
        return const Color(0xFFFF3B30); // red
      case _ToastType.warning:
        return const Color(0xFFFFB020); // amber
      case _ToastType.info:
        return const Color(0xFF3B82F6); // blue
    }
  }

  IconData get _icon {
    switch (widget.type) {
      case _ToastType.success:
        return Icons.check_circle_rounded;
      case _ToastType.error:
        return Icons.error_rounded;
      case _ToastType.warning:
        return Icons.warning_rounded;
      case _ToastType.info:
        return Icons.info_rounded;
    }
  }

  /// The icon + message row, exactly as it will be painted --- reused for
  /// both the invisible measurer and the real visible pill so they are
  /// guaranteed to size identically.
  Widget _buildContent({Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(_icon, color: _accentColor, size: _iconSize),
          ),
          const SizedBox(width: _iconGap),
          Flexible(
            // IntrinsicWidth forces the Row to prefer the max width of the 
            // whole sentence rather than shrink-wrapping to the longest word.
            child: IntrinsicWidth(
              child: Text(
                widget.message,
                softWrap: true,
                style: _textStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    // Sits roughly where a front camera cutout would be.
    final topOffset = topInset + 6;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxPillWidth = math.min(_maxOpenWidth, screenWidth - 32);

    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            // Hidden measurer: laid out (but never painted) so we can read
            // back its *real* size --- the same size the live pill will use.
            Offstage(
              offstage: true,
              child: Material(
                type: MaterialType.transparency,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxPillWidth),
                  child: _buildContent(key: _measureKey),
                ),
              ),
            ),
            Center(
              child: !_measured
                  ? _buildDot()
                  : AnimatedBuilder(
                      animation:
                          Listenable.merge([_sizeController, _fadeController]),
                      builder: (context, child) {
                        final t = _sizeController.value.clamp(0.0, 1.0);
                        final opacity = _fadeController.value.clamp(0.0, 1.0);

                        final width = lerpDouble(baseSize, _openWidth, t)!;
                        final height = lerpDouble(baseSize, _openHeight, t)!;

                        // Full pill/circle at the extremes, capped so a
                        // tall multi-line pill reads as rounded-rect
                        // rather than a stadium.
                        final radius = math.min(height / 2, 26.0);

                        return Container(
                          width: width,
                          height: height,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0B0D),
                            borderRadius: BorderRadius.circular(radius),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          child: Material(
                            type: MaterialType.transparency,
                            child: Opacity(
                              opacity: opacity,
                              child: _buildContent(),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot() {
    return Container(
      width: baseSize,
      height: baseSize,
      decoration: const BoxDecoration(
        color: Color(0xFF0B0B0D),
        shape: BoxShape.circle,
      ),
    );
  }
}