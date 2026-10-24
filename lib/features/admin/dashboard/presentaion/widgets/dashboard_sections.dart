import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/nx_ui.dart';
import '../../data/models/mobile_dashboard_response_model.dart';

/// Shared formatting for the dashboard widgets.
class DashboardFormat {
  DashboardFormat._();

  static final NumberFormat _money = NumberFormat('#,##0.00');

  /// 12500 -> "LKR 12,500.00"
  static String lkr(num value) => 'LKR ${_money.format(value)}';

  static String money(num value) => _money.format(value);
}

/// Common white card used by every section.
class DashboardCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  const DashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: AppColors.radiusLarge,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: child,
    );
  }
}

/// "Today's Classes            See all >"
class DashboardSectionTitle extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;

  const DashboardSectionTitle({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return NxSectionTitle(
      title: title,
      actionText: actionText,
      onAction: onAction,
    );
  }
}

/*
|--------------------------------------------------------------------------
| Alerts
|--------------------------------------------------------------------------
*/

class DashboardAlertsList extends StatelessWidget {
  final List<DashboardAlert> alerts;

  const DashboardAlertsList({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final alert in alerts) ...[
          _AlertTile(alert: alert),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 6),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final DashboardAlert alert;

  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) {
    final (NxTone tone, IconData icon) = switch (alert.level) {
      'danger' => (NxTone.red, Icons.error_rounded),
      'warning' => (NxTone.amber, Icons.warning_amber_rounded),
      _ => (NxTone.blue, Icons.info_rounded),
    };

    return NxAlert(message: alert.message, tone: tone, icon: icon);
  }
}

/*
|--------------------------------------------------------------------------
| Collection (today money)
|--------------------------------------------------------------------------
*/

class CollectionSummaryCard extends StatelessWidget {
  final DashboardCollection collection;

  /// Cashier: highlight "My Collection"
  final bool highlightMine;
  final VoidCallback? onTap;

  const CollectionSummaryCard({
    super.key,
    required this.collection,
    this.highlightMine = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppColors.radiusLarge,
      child: DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const NxIconBox(
                  icon: Icons.account_balance_wallet_rounded,
                  tone: NxTone.green,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Today's Collection",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.dark,
                    ),
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                DashboardFormat.lkr(collection.todayTotal),
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MoneyLine(
                    label: 'Class Fees (${collection.todayClassFeeCount})',
                    value: collection.todayClassFees,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MoneyLine(
                    label: 'Admissions (${collection.todayAdmissionCount})',
                    value: collection.todayAdmissions,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _MoneyLine(
                    label: 'My Collection (${collection.myTodayCount})',
                    value: collection.myToday,
                    highlight: highlightMine,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MoneyLine(
                    label: 'This Month',
                    value: collection.monthTotal,
                  ),
                ),
              ],
            ),
            if (collection.todayDiscount > 0) ...[
              const SizedBox(height: 10),
              Text(
                'Discounts today: ${DashboardFormat.lkr(collection.todayDiscount)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (collection.byMethod.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in collection.byMethod)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.headBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${m.label}: ${DashboardFormat.money(m.amount)} (${m.count})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkLight,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  final String label;
  final double value;
  final bool highlight;

  const _MoneyLine({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight ? AppColors.primaryLight : AppColors.surfaceSecondary,
        borderRadius: AppColors.radiusMedium,
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: .3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              DashboardFormat.money(value),
              maxLines: 1,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.primary : AppColors.dark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/*
|--------------------------------------------------------------------------
| Finance (Admin / Branch Admin)
|--------------------------------------------------------------------------
*/

class FinanceSummaryCard extends StatelessWidget {
  final DashboardFinance finance;

  const FinanceSummaryCard({super.key, required this.finance});

  @override
  Widget build(BuildContext context) {
    final positive = finance.net >= 0;

    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Student collection', finance.studentCollection),
          _row('Extra income', finance.extraIncome),
          _row('Total income', finance.totalIncome, bold: true),
          const Divider(height: 20, color: AppColors.divider),
          _row('Expenses', finance.expenses, negative: true),
          _row('Teacher advances', finance.teacherAdvances, negative: true),
          _row('Total outgoing', finance.totalOutgoing, bold: true, negative: true),
          const Divider(height: 20, color: AppColors.divider),
          Row(
            children: [
              Icon(
                positive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: positive ? AppColors.successText : AppColors.dangerText,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Net today',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
              ),
              Text(
                DashboardFormat.lkr(finance.net),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: positive ? AppColors.successText : AppColors.dangerText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    double value, {
    bool bold = false,
    bool negative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? AppColors.dark : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            '${negative && value > 0 ? '- ' : ''}${DashboardFormat.money(value)}',
            style: TextStyle(
              color: negative && value > 0 ? AppColors.dangerText : AppColors.dark,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/*
|--------------------------------------------------------------------------
| Today's classes
|--------------------------------------------------------------------------
*/

class TodayClassesList extends StatelessWidget {
  final List<TodayClassModel> classes;

  /// Show the branch name on each row (when looking at all branches)
  final bool showBranch;

  const TodayClassesList({
    super.key,
    required this.classes,
    this.showBranch = false,
  });

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) {
      return const DashboardCard(
        child: _EmptyText(
          icon: Icons.event_available_rounded,
          text: 'No classes today',
        ),
      );
    }

    return DashboardCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < classes.length; i++) ...[
            _TodayClassTile(item: classes[i], showBranch: showBranch),
            if (i != classes.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _TodayClassTile extends StatelessWidget {
  final TodayClassModel item;
  final bool showBranch;

  const _TodayClassTile({required this.item, required this.showBranch});

  @override
  Widget build(BuildContext context) {
    final (String label, NxTone tone) = switch (item.status) {
      'ongoing' => ('Ongoing', NxTone.green),
      'completed' => ('Completed', NxTone.gray),
      'cancelled' => ('Cancelled', NxTone.red),
      _ => ('Scheduled', NxTone.blue),
    };

    final subtitle = [
      if (item.teacherName != null) item.teacherName!,
      if (item.hallName != null) item.hallName!,
      if (showBranch && item.branchName != null) item.branchName!,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time
          SizedBox(
            width: 52,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.startTime ?? '--:--',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.dark,
                  ),
                ),
                if (item.endTime != null)
                  Text(
                    item.endTime!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.className,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                    decoration: item.isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                if (item.isCancelled)
                  Text(
                    item.cancelReason == null
                        ? 'Class cancelled'
                        : 'Cancelled: ${item.cancelReason}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.dangerText,
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: NxProgress(
                          value: item.attendanceRate,
                          tone: tone == NxTone.gray ? NxTone.blue : tone,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${item.attendedCount}/${item.enrolledCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkLight,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          NxBadge(label, tone: tone),
        ],
      ),
    );
  }
}

/*
|--------------------------------------------------------------------------
| Recent payments
|--------------------------------------------------------------------------
*/

class RecentPaymentsList extends StatelessWidget {
  final List<RecentPaymentModel> payments;

  const RecentPaymentsList({super.key, required this.payments});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const DashboardCard(
        child: _EmptyText(
          icon: Icons.receipt_long_rounded,
          text: 'No payments yet today',
        ),
      );
    }

    return DashboardCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < payments.length; i++) ...[
            _PaymentTile(item: payments[i]),
            if (i != payments.length - 1)
              const Divider(height: 1, indent: 16, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final RecentPaymentModel item;

  const _PaymentTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final details = [
      if (item.className != null) item.className!,
      if (item.paymentMonth != null) item.paymentMonth!,
    ].join(' • ');

    final footer = [
      item.paidTime,
      if (item.receiptNumber != null) '#${item.receiptNumber}',
      if (item.collectedBy != null) item.collectedBy!,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.successLight,
            child: Text(
              item.studentName.isNotEmpty
                  ? item.studentName[0].toUpperCase()
                  : 'S',
              style: const TextStyle(
                color: AppColors.successText,
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
                  item.studentCustomId == null
                      ? item.studentName
                      : '${item.studentName} (${item.studentCustomId})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark,
                  ),
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                Text(
                  footer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DashboardFormat.money(item.amount),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.dark,
                ),
              ),
              const SizedBox(height: 4),
              NxBadge(
                PaymentMethodTotal(
                  method: item.paymentMethod,
                  amount: 0,
                  count: 0,
                ).label,
                tone: item.paymentMethod == 'cash' ? NxTone.green : NxTone.info,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/*
|--------------------------------------------------------------------------
| ID card stock
|--------------------------------------------------------------------------
*/

class CardStockCard extends StatelessWidget {
  final DashboardCardStock cards;

  /// false = the institute only uses permanent cards
  final bool showTemporary;

  const CardStockCard({
    super.key,
    required this.cards,
    this.showTemporary = true,
  });

  @override
  Widget build(BuildContext context) {
    final permanent = _StockBox(
      title: 'Permanent Cards',
      count: cards.permanentAvailable,
      level: cards.permanentLevel,
      icon: Icons.credit_card_rounded,
    );

    if (!showTemporary) return permanent;

    return Row(
      children: [
        Expanded(child: permanent),
        const SizedBox(width: 12),
        Expanded(
          child: _StockBox(
            title: 'Temporary Cards',
            count: cards.temporaryAvailable,
            level: cards.temporaryLevel,
            icon: Icons.qr_code_2_rounded,
          ),
        ),
      ],
    );
  }
}

class _StockBox extends StatelessWidget {
  final String title;
  final int count;
  final String level;
  final IconData icon;

  const _StockBox({
    required this.title,
    required this.count,
    required this.level,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final (NxTone tone, String text) = switch (level) {
      'critical' => (NxTone.red, 'CRITICAL'),
      'low' => (NxTone.amber, 'LOW'),
      _ => (NxTone.green, 'OK'),
    };

    return DashboardCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NxIconBox(icon: icon, tone: tone, size: 36),
              const Spacer(),
              NxBadge(text, tone: tone),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.dark,
            ),
          ),
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              letterSpacing: .4,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/*
|--------------------------------------------------------------------------
| Small pieces
|--------------------------------------------------------------------------
*/

class _EmptyText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
