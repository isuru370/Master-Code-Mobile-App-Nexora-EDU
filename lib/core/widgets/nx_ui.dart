import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Building blocks that copy the web panel (nx-* classes), so every screen
/// of the app looks like the website.
///
///   NxCard            .nx-card (+ .nx-card-header)
///   NxStatCard        .stat-card
///   NxQuickAction     .nx-quick-action
///   NxBadge           .nx-badge-*
///   NxAlert           .nx-alert-*
///   NxHero            .hero-section
///   NxSectionTitle    .nx-section-title
///   NxIconBox         .stat-icon-wrapper / .qa-icon
///   NxProgress        .nx-progress
///   NxEmpty           .empty-table
///   NxPageTitle       top navbar page title (title + small subtitle)
///   NxDrawer...       the dark sidebar

/* ------------------------------------------------------------------------ */
/* Tones (blue / green / amber / red / violet / gray / info)                */
/* ------------------------------------------------------------------------ */

enum NxTone {
  blue(AppColors.primary, AppColors.primaryLight),
  green(AppColors.successText, AppColors.successLight),
  amber(AppColors.warningText, AppColors.warningLight),
  red(AppColors.dangerText, AppColors.dangerLight),
  violet(AppColors.violet, AppColors.violetLight),
  info(AppColors.infoText, AppColors.infoLight),
  gray(AppColors.textSecondary, AppColors.headBackground);

  /// Text / icon colour
  final Color fg;

  /// Soft background
  final Color bg;

  const NxTone(this.fg, this.bg);
}

/* ------------------------------------------------------------------------ */
/* Card                                                                     */
/* ------------------------------------------------------------------------ */

class NxCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Optional header strip (title, subtitle, icon, trailing action)
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  const NxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);

    final content = title == null
        ? body
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _NxCardHeader(
                title: title!,
                subtitle: subtitle,
                icon: icon,
                trailing: trailing,
              ),
              body,
            ],
          );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: color ?? AppColors.cardBackground,
        borderRadius: AppColors.radiusLarge,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ClipRRect(
          borderRadius: AppColors.radiusLarge,
          child: onTap == null
              ? content
              : InkWell(onTap: onTap, child: content),
        ),
      ),
    );
  }
}

class _NxCardHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;

  const _NxCardHeader({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: const BoxDecoration(
        color: AppColors.cardHeader,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* Icon box                                                                 */
/* ------------------------------------------------------------------------ */

class NxIconBox extends StatelessWidget {
  final IconData icon;
  final NxTone tone;
  final double size;

  const NxIconBox({
    super.key,
    required this.icon,
    this.tone = NxTone.blue,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: AppColors.radiusMedium,
      ),
      child: Icon(icon, color: tone.fg, size: size * .5),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* Stat card                                                                */
/* ------------------------------------------------------------------------ */

class NxStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final NxTone tone;

  /// Small grey line under the number
  final String? note;
  final VoidCallback? onTap;

  const NxStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tone = NxTone.blue,
    this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NxCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NxIconBox(icon: icon, tone: tone, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .4,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 21,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                if (note != null && note!.isNotEmpty)
                  Text(
                    note!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* Quick action                                                             */
/* ------------------------------------------------------------------------ */

class NxQuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final NxTone tone;
  final VoidCallback onTap;

  const NxQuickAction({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.tone = NxTone.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: AppColors.radiusMedium,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppColors.radiusMedium,
        splashColor: AppColors.primaryLight,
        highlightColor: AppColors.primaryLight.withValues(alpha: .6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              NxIconBox(icon: icon, tone: tone, size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: AppColors.dark,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* Badge                                                                    */
/* ------------------------------------------------------------------------ */

class NxBadge extends StatelessWidget {
  final String label;
  final NxTone tone;
  final IconData? icon;

  const NxBadge(this.label, {super.key, this.tone = NxTone.gray, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: tone.fg,
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* Alert                                                                    */
/* ------------------------------------------------------------------------ */

class NxAlert extends StatelessWidget {
  final String message;
  final NxTone tone;
  final IconData? icon;
  final Widget? action;

  const NxAlert({
    super.key,
    required this.message,
    this.tone = NxTone.blue,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(14, action == null ? 12 : 4, 8, action == null ? 12 : 4),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: AppColors.radiusSmall,
        border: Border.all(color: tone.fg.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(icon ?? Icons.info_rounded, color: tone.fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tone.fg,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* Hero (dark welcome box)                                                  */
/* ------------------------------------------------------------------------ */

class NxHero extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const NxHero({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: AppColors.radiusLarge,
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: AppColors.heroGlow,
          borderRadius: AppColors.radiusLarge,
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: Color(0xFFF1F4FB)),
          child: child,
        ),
      ),
    );
  }
}

/// Small translucent box inside [NxHero] (date / role / branch ...)
class NxHeroChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const NxHeroChip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: AppColors.radiusSmall,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* Section title                                                            */
/* ------------------------------------------------------------------------ */

class NxSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? actionText;
  final VoidCallback? onAction;

  const NxSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (actionText != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(actionText!, style: const TextStyle(fontSize: 13)),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* Progress                                                                 */
/* ------------------------------------------------------------------------ */

class NxProgress extends StatelessWidget {
  /// 0..1
  final double value;
  final NxTone tone;

  const NxProgress({super.key, required this.value, this.tone = NxTone.blue});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1).toDouble(),
        minHeight: 6,
        backgroundColor: const Color(0xFFDDE3EC),
        color: tone.fg,
      ),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* Empty / error                                                            */
/* ------------------------------------------------------------------------ */

class NxEmpty extends StatelessWidget {
  final IconData icon;
  final String message;
  final NxTone tone;
  final VoidCallback? onRetry;
  final String retryText;

  const NxEmpty({
    super.key,
    required this.icon,
    required this.message,
    this.tone = NxTone.gray,
    this.onRetry,
    this.retryText = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NxIconBox(icon: icon, tone: tone, size: 52),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(140, 42)),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(retryText),
            ),
          ],
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* App bar title                                                            */
/* ------------------------------------------------------------------------ */

/// "Dashboard" with a small grey line under it, like the web page title.
class NxPageTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? subtitleIcon;
  final VoidCallback? onTap;

  const NxPageTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.subtitleIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitleIcon != null) ...[
                Icon(subtitleIcon, size: 13, color: AppColors.textSecondary),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
      ],
    );

    if (onTap == null) return column;

    return InkWell(
      onTap: onTap,
      borderRadius: AppColors.radiusSmall,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: column,
      ),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* Drawer (web sidebar)                                                     */
/* ------------------------------------------------------------------------ */

class NxDrawer extends StatelessWidget {
  /// Top part (brand + user)
  final Widget header;

  /// Sections and items
  final List<Widget> children;

  /// Bottom part (logout)
  final Widget? footer;

  const NxDrawer({
    super.key,
    required this.header,
    required this.children,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
      child: Container(
        decoration: const BoxDecoration(gradient: AppColors.sidebarGradient),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              const Divider(color: AppColors.sidebarBorder, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  children: children,
                ),
              ),
              if (footer != null) ...[
                const Divider(color: AppColors.sidebarBorder, height: 1),
                Padding(padding: const EdgeInsets.all(12), child: footer),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Brand row + signed-in user, for the top of [NxDrawer].
class NxDrawerHeader extends StatelessWidget {
  final String brand;
  final String brandSubtitle;
  final String userName;
  final String? userDetail;
  final String? roleLabel;

  const NxDrawerHeader({
    super.key,
    this.brand = 'NexoraEDU',
    this.brandSubtitle = 'Education Management',
    required this.userName,
    this.userDetail,
    this.roleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final initial = userName.trim().isEmpty
        ? 'U'
        : userName.trim()[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryBright,
                  borderRadius: AppColors.radiusMedium,
                ),
                child: Text(
                  brand.isEmpty ? 'N' : brand[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      brand,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      brandSubtitle,
                      style: const TextStyle(
                        color: AppColors.sidebarTitle,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .06),
              borderRadius: AppColors.radiusMedium,
              border: Border.all(color: AppColors.sidebarBorder),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: AppColors.primaryBright,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (userDetail != null && userDetail!.isNotEmpty)
                        Text(
                          userDetail!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.sidebarText,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                if (roleLabel != null && roleLabel!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBright.withValues(alpha: .25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      roleLabel!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "STUDENT MANAGEMENT"
class NxDrawerSection extends StatelessWidget {
  final String title;

  const NxDrawerSection(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.sidebarTitle,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class NxDrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  const NxDrawerItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.active = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger
        ? const Color(0xFFFCA5A5)
        : active
        ? Colors.white
        : AppColors.sidebarText;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: active ? AppColors.primaryBright : Colors.transparent,
        borderRadius: AppColors.radiusMedium,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppColors.radiusMedium,
          splashColor: Colors.white.withValues(alpha: .08),
          highlightColor: Colors.white.withValues(alpha: .06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------------ */
/* Navy background (web login page)                                         */
/* ------------------------------------------------------------------------ */

/// Dark blue page background with soft glows and circles, like the web
/// login page. Used by the login and splash screens.
class NxNavyBackground extends StatelessWidget {
  final Widget child;

  const NxNavyBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    Widget circle(double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .05),
      ),
    );

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E3A8A)],
        ),
      ),
      child: Stack(
        children: [
          // glows
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topLeft,
                  radius: .9,
                  colors: [Color(0x471D4ED8), Color(0x001D4ED8)],
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.bottomRight,
                  radius: .9,
                  colors: [Color(0x2E3B82F6), Color(0x003B82F6)],
                ),
              ),
            ),
          ),
          // floating circles
          Positioned(top: -60, left: -60, child: circle(240)),
          Positioned(bottom: -50, right: -40, child: circle(180)),
          Positioned(top: 140, right: 50, child: circle(90)),
          child,
        ],
      ),
    );
  }
}
