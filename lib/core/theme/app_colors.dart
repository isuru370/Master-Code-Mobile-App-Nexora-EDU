import 'package:flutter/material.dart';

/// Colours, radii and shadows of the web panel (nexoraEDU nx-* theme), so the
/// app looks like the website.
///
/// Web source: resources/views/layouts/partials/nexora-theme.blade.php and
/// layouts/sidebar.blade.php.
class AppColors {
  // =========================
  // BRAND COLORS
  // =========================

  /// --nx-blue (buttons, links, active items)
  static const Color primary = Color(0xFF1D4ED8);

  /// Sidebar active item / brand icon (--nx-sidebar-active)
  static const Color primaryBright = Color(0xFF2563EB);

  static const Color primaryDark = Color(0xFF1E3A8A);

  /// --nx-blue-soft
  static const Color primaryLight = Color(0xFFDBE6FF);

  static const Color secondary = Color(0xFF64748B);

  // =========================
  // STATUS COLORS
  // (bright = icons/progress, *Text = text on the soft background)
  // =========================

  static const Color success = Color(0xFF10B981);
  static const Color successText = Color(0xFF047857);
  static const Color successLight = Color(0xFFD1FAE5);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningText = Color(0xFFB45309);
  static const Color warningLight = Color(0xFFFEF3C7);

  static const Color danger = Color(0xFFEF4444);
  static const Color dangerText = Color(0xFFB91C1C);
  static const Color dangerLight = Color(0xFFFEE2E2);

  static const Color info = Color(0xFF0EA5E9);
  static const Color infoText = Color(0xFF0369A1);
  static const Color infoLight = Color(0xFFE0F2FE);

  static const Color violet = Color(0xFF6D28D9);
  static const Color violetLight = Color(0xFFEDE9FE);

  // =========================
  // BACKGROUND COLORS
  // =========================

  /// --nx-bg (page background)
  static const Color background = Color(0xFFEEF1F6);
  static const Color surface = Colors.white;

  /// Quick action / search strip background (#f4f6fa)
  static const Color surfaceSecondary = Color(0xFFF4F6FA);

  /// Card header strip (#fafbfd)
  static const Color cardHeader = Color(0xFFFAFBFD);

  /// Table head / grey badge (--nx-head-bg)
  static const Color headBackground = Color(0xFFE5EAF2);

  // =========================
  // DARK COLORS
  // =========================

  /// --nx-navy (hero, text)
  static const Color dark = Color(0xFF0F172A);
  static const Color darkLight = Color(0xFF1E293B);

  // =========================
  // SIDEBAR (drawer)
  // =========================

  static const Color sidebarTitle = Color(0xFF8894B3);
  static const Color sidebarText = Color(0xFFB8C2DA);
  static const Color sidebarBorder = Color(0x0FFFFFFF);

  // =========================
  // TEXT COLORS
  // =========================

  static const Color textPrimary = dark;

  /// --nx-muted
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textWhite = Colors.white;

  // =========================
  // BORDER COLORS
  // =========================

  /// --nx-border
  static const Color border = Color(0xFFD1D8E3);
  static const Color divider = Color(0xFFE2E8F0);

  // =========================
  // INPUT COLORS
  // =========================

  static const Color inputFill = Colors.white;
  static const Color inputBorder = border;

  // =========================
  // CARD COLORS
  // =========================

  static const Color cardBackground = Colors.white;

  // =========================
  // GRADIENTS
  // =========================

  /// Web sidebar
  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF141C3A), Color(0xFF1A2344), Color(0xFF1E293B)],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
  );

  /// Web hero: navy with a blue glow in the top right corner
  static const RadialGradient heroGlow = RadialGradient(
    center: Alignment.topRight,
    radius: 1.1,
    colors: [Color(0x661D4ED8), Color(0x001D4ED8)],
    stops: [0, .55],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F172A), Color(0xFF0F172A), Color(0xFF172554)],
  );

  // =========================
  // SHADOWS (--nx-shadow)
  // =========================

  static List<BoxShadow> softShadow = const [
    BoxShadow(color: Color(0x0F0F172A), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static List<BoxShadow> mediumShadow = const [
    BoxShadow(color: Color(0x140F172A), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static List<BoxShadow> largeShadow = const [
    BoxShadow(color: Color(0x1F0F172A), blurRadius: 16, offset: Offset(0, 4)),
  ];

  // =========================
  // BORDER RADIUS
  // =========================

  /// Buttons, inputs, badges (8px on the web)
  static BorderRadius radiusSmall = BorderRadius.circular(8);

  /// Sidebar items, icon boxes, quick actions (10px)
  static BorderRadius radiusMedium = BorderRadius.circular(10);

  /// Cards (--nx-radius 12px)
  static BorderRadius radiusLarge = BorderRadius.circular(12);

  /// Sheets / dialogs
  static BorderRadius radiusXLarge = BorderRadius.circular(16);

  // =========================
  // SPACING
  // =========================

  static const double paddingSmall = 8;
  static const double paddingMedium = 16;
  static const double paddingLarge = 24;
  static const double spacingLarge = 24;
  static const double spacingXLarge = 32;

  // =========================
  // ICON COLORS
  // =========================

  static const Color iconPrimary = dark;
  static const Color iconSecondary = secondary;
  static const Color iconLight = Colors.white;
}
