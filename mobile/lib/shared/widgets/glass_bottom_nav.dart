import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travel_os/core/theme/app_theme.dart';

class MainNavigationShell extends StatelessWidget {
  final Widget child;

  const MainNavigationShell({
    super.key,
    required this.child,
  });

  int _getSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/trips')) {
      return 1;
    } else if (location.startsWith('/plan')) {
      return 2;
    } else if (location.startsWith('/expenses')) {
      return 3;
    } else if (location.startsWith('/favorites')) {
      return 4;
    } else if (location.startsWith('/profile')) {
      return 5;
    } else if (location.startsWith('/help')) {
      return 6;
    }
    return 0; // default '/' (Home)
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        context.go('/trips');
        break;
      case 2:
        context.go('/plan');
        break;
      case 3:
        context.go('/expenses');
        break;
      case 4:
        context.go('/favorites');
        break;
      case 5:
        context.go('/profile');
        break;
      case 6:
        context.go('/help');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);

    // Hide bottom navigation bar when viewing trip details
    final location = GoRouterState.of(context).matchedLocation;
    final isTripDetail = location.startsWith('/trips/') && location.length > 7;

    return Scaffold(
      extendBody: true, // Enables rendering under the bottom navigation
      body: child,
      bottomNavigationBar: isTripDetail
          ? null
          : Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(
                          index: 0,
                          icon: Icons.home_rounded,
                          activeIcon: Icons.home_rounded,
                          label: 'Home',
                          isSelected: selectedIndex == 0,
                          context: context,
                        ),
                        _buildNavItem(
                          index: 1,
                          icon: Icons.card_travel_rounded,
                          activeIcon: Icons.card_travel_rounded,
                          label: 'Trips',
                          isSelected: selectedIndex == 1,
                          context: context,
                        ),
                        _buildNavItem(
                          index: 2,
                          icon: Icons.auto_awesome_rounded,
                          activeIcon: Icons.auto_awesome_rounded,
                          label: 'AI Plan',
                          isSelected: selectedIndex == 2,
                          context: context,
                          isHighlight: true,
                        ),
                        _buildNavItem(
                          index: 3,
                          icon: Icons.account_balance_wallet_rounded,
                          activeIcon: Icons.account_balance_wallet_rounded,
                          label: 'Expenses',
                          isSelected: selectedIndex == 3,
                          context: context,
                        ),
                        _buildNavItem(
                          index: 4,
                          icon: Icons.favorite_border_rounded,
                          activeIcon: Icons.favorite_rounded,
                          label: 'Favorites',
                          isSelected: selectedIndex == 4,
                          context: context,
                        ),
                        _buildNavItem(
                          index: 5,
                          icon: Icons.person_rounded,
                          activeIcon: Icons.person_rounded,
                          label: 'Profile',
                          isSelected: selectedIndex == 5,
                          context: context,
                        ),
                        _buildNavItem(
                          index: 6,
                          icon: Icons.help_outline_rounded,
                          activeIcon: Icons.help_rounded,
                          label: 'Help',
                          isSelected: selectedIndex == 6,
                          context: context,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
    required BuildContext context,
    bool isHighlight = false,
  }) {
    if (isHighlight) {
      return GestureDetector(
        onTap: () => _onItemTapped(index, context),
        child: Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: AppTheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x33166534),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            activeIcon,
            color: Colors.white,
            size: 26,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _onItemTapped(index, context),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary.withOpacity(0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppTheme.primary : AppTheme.mutedText,
              size: 22,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'DM Sans',
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppTheme.primary : AppTheme.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
