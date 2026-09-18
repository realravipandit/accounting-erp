import 'package:flutter/material.dart';

// ============================================================================
// APP BOTTOM NAV — 5 tabs, sliding glow indicator, badges
//
// Generic app-wide navigation chrome — lives in shared/widgets, not tied to
// the dashboard feature. Used by HomePage.
// ============================================================================

class AppNavItemData {
  final IconData icon;
  final String label;
  final bool isMore;
  const AppNavItemData({required this.icon, required this.label, this.isMore = false});
}

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onMoreTap;
  final int transactionsBadgeCount;
  final int inventoryBadgeCount;
  final double contentHeight;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onMoreTap,
    required this.transactionsBadgeCount,
    required this.inventoryBadgeCount,
    this.contentHeight = 68,
  });

  static const List<AppNavItemData> items = [
    AppNavItemData(icon: Icons.grid_view_rounded, label: 'Dashboard'),
    AppNavItemData(icon: Icons.receipt_long_rounded, label: 'Transactions'),
    AppNavItemData(icon: Icons.people_alt_rounded, label: 'Parties'),
    AppNavItemData(icon: Icons.inventory_2_rounded, label: 'Inventory'),
    AppNavItemData(icon: Icons.more_horiz_rounded, label: 'More', isMore: true),
  ];

  static const Color _kActive = Color(0xFF0891B2);
  static const Color _kInactive = Color(0xFF9CA3AF);
  static const Color _kBorder = Color(0xFFE5E7EB);
  static const Color _kBadgeRed = Color(0xFFEF4444);
  static const Color _kBadgeOrange = Color(0xFFF59E0B);

  Widget _buildBadge(int count, Color color) {
    if (count <= 0) return const SizedBox.shrink();
    return Positioned(
      top: -8,
      right: -10,
      child: Container(
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 5, offset: const Offset(0, 2))],
        ),
        child: Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _kBorder, width: 0.75)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: contentHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth / items.length;
              return Stack(
                children: [
                  // Sliding glow — physically translates to the selected tab.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: const Cubic(0.34, 1.2, 0.64, 1.0),
                    left: itemWidth * currentIndex,
                    top: 8,
                    bottom: 12,
                    width: itemWidth,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: _kActive.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: _kActive.withValues(alpha: 0.35), blurRadius: 14)],
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(items.length, (i) {
                      final item = items[i];
                      final selected = !item.isMore && i == currentIndex;
                      final badgeCount = i == 1
                          ? transactionsBadgeCount
                          : i == 3
                              ? inventoryBadgeCount
                              : 0;
                      final badgeColor = i == 1 ? _kBadgeRed : _kBadgeOrange;

                      return SizedBox(
                        width: itemWidth,
                        child: InkWell(
                          onTap: () => item.isMore ? onMoreTap() : onTap(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  TweenAnimationBuilder<Color?>(
                                    tween: ColorTween(end: selected ? _kActive : _kInactive),
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                    builder: (context, color, _) => Icon(item.icon, size: 20, color: color),
                                  ),
                                  _buildBadge(badgeCount, badgeColor),
                                ],
                              ),
                              const SizedBox(height: 3),
                              TweenAnimationBuilder<Color?>(
                                tween: ColorTween(end: selected ? _kActive : _kInactive),
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOut,
                                builder: (context, color, _) => Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// FLOATING "NEW TRANSACTION" PILL
// ============================================================================

class TransactionPill extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  const TransactionPill({super.key, required this.isSelected, required this.onTap});

  static const Color _kFill = Color(0xFFF0A860);
  static const Color _kText = Color(0xFF3A2410);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.only(left: 14, right: 18),
          decoration: BoxDecoration(
            color: _kFill,
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(color: _kFill.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedRotation(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                turns: isSelected ? 0.125 : 0,
                child: const Icon(Icons.add_rounded, color: _kText, size: 22),
              ),
              const SizedBox(width: 7),
              const Text('New transaction', style: TextStyle(color: _kText, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}