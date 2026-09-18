import 'package:flutter/material.dart';

// ============================================================================
// FADE INDEXED STACK
//
// Same contract as IndexedStack (all children stay mounted --- no lost
// scroll position, no re-fetching data on tab switch) but cross-fades
// between the active and previous child instead of an instant cut.
// ============================================================================

class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;
  final Curve curve;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 240),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (i) {
        final isActive = i == widget.index;
        return IgnorePointer(
          ignoring: !isActive,
          child: AnimatedOpacity(
            opacity: isActive ? 1.0 : 0.0,
            duration: widget.duration,
            curve: widget.curve,
            // Stays mounted (state preserved) even while faded out ---
            // same guarantee IndexedStack gave you, just animated.
            child: TickerMode(
              enabled: isActive,
              child: widget.children[i],
            ),
          ),
        );
      }),
    );
  }
}