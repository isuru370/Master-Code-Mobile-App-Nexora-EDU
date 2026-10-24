import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class TeacherBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const TeacherBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Web style: white bar with a thin top line, soft blue pill on the
    // selected item
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,

      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,

      height: 68,

      indicatorColor: AppColors.primaryLight,
      indicatorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),

      labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }

          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          );
        },
      ),

      destinations: const [
        NavigationDestination(
          icon: Icon(
            Icons.home_outlined,
            color: AppColors.textSecondary,
          ),
          selectedIcon: Icon(
            Icons.home_rounded,
            color: AppColors.primary,
          ),
          label: 'Home',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.menu_book_outlined,
            color: AppColors.textSecondary,
          ),
          selectedIcon: Icon(
            Icons.menu_book_rounded,
            color: AppColors.primary,
          ),
          label: 'Classes',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.calendar_month_outlined,
            color: AppColors.textSecondary,
          ),
          selectedIcon: Icon(
            Icons.calendar_month_rounded,
            color: AppColors.primary,
          ),
          label: 'Timetable',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.groups_outlined,
            color: AppColors.textSecondary,
          ),
          selectedIcon: Icon(
            Icons.groups_rounded,
            color: AppColors.primary,
          ),
          label: 'Students',
        ),

        NavigationDestination(
          icon: Icon(
            Icons.person_outline_rounded,
            color: AppColors.textSecondary,
          ),
          selectedIcon: Icon(
            Icons.person_rounded,
            color: AppColors.primary,
          ),
          label: 'Profile',
        ),
      ],
      ),
    );
  }
}