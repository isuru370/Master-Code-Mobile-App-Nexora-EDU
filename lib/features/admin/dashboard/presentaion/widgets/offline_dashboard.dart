import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../core/offline/offline_banner.dart';
import '../../../../../core/offline/offline_sync.dart';
import '../../../../../core/theme/app_colors.dart';

/// Dashboard pieces that work with and without internet (offline mode):
/// the sync card, the work buttons, today's numbers, what is saved on this
/// phone and today's classes from the day's offline data.

const _border = Color(0xFFE2E8F0);
const _soft = Color(0xFFF1F5F9);

String _time(DateTime t) => DateFormat('h:mm a').format(t);

String _money(double v) => v >= 100000
    ? 'Rs ${(v / 1000).toStringAsFixed(0)}k'
    : v >= 10000
        ? 'Rs ${(v / 1000).toStringAsFixed(1)}k'
        : 'Rs ${NumberFormat('#,##0').format(v)}';

void _openItems(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OfflineItemsPage()));

class _Title extends StatelessWidget {
  const _Title(this.title, {this.note, this.action, this.onAction});
  final String title;
  final String? note;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          ),
          if (note != null) Text(note!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(minimumSize: const Size(44, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text(action!, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/* ================================================================ hero */

/// The sync card at the top: online / offline / send time passed, items
/// waiting, "send by" (end of today's last class) and Sync now.
class OfflineSyncHero extends StatelessWidget {
  const OfflineSyncHero({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineStatus>(
      valueListenable: OfflineSync.instance.status,
      builder: (context, s, _) {
        final now = DateTime.now();
        final late = s.pending > 0 && s.syncAt != null && now.isAfter(s.syncAt!);

        final Color bg;
        final String kicker;
        final String title;
        final String foot;
        final String button;
        if (late) {
          bg = AppColors.dangerText;
          kicker = s.online ? 'Send time passed' : 'Offline · send time passed';
          title = 'Connect to the internet';
          foot = 'Do not log out. Items are safe on this phone.';
          button = 'Try again';
        } else if (!s.online) {
          bg = AppColors.darkLight;
          kicker = s.readyToday ? 'Offline · working from today\'s data' : 'Offline · today\'s data not downloaded';
          title = s.readyToday ? 'Attendance and payments still work' : 'Connect once to download today\'s classes';
          foot = 'Checks every minute';
          button = 'Try now';
        } else {
          bg = AppColors.successText;
          kicker = s.readyToday ? 'Online · ready for today' : 'Online · downloading today\'s data';
          title = s.pending == 0 ? 'All sent to the server' : 'Sending...';
          foot = s.lastSync == null ? 'Checks every minute' : 'Last sync ${_time(s.lastSync!)}';
          button = 'Sync now';
        }

        final String countdown;
        double progress = 0;
        if (s.syncAt == null || !s.readyToday) {
          countdown = s.readyToday ? 'No classes today' : '';
        } else {
          final left = s.syncAt!.difference(now);
          if (left.isNegative) {
            final over = -left.inMinutes;
            countdown = over >= 60 ? '${over ~/ 60}h ${over % 60}m late' : '$over min ${s.pending > 0 ? 'late' : 'ago'}';
            progress = 1;
          } else {
            countdown = left.inHours > 0 ? '${left.inHours}h ${left.inMinutes % 60}m left' : '${left.inMinutes} min left';
            final from = s.generatedAt ?? DateTime(now.year, now.month, now.day, 6);
            final total = s.syncAt!.difference(from).inSeconds;
            progress = total <= 0 ? 0 : (now.difference(from).inSeconds / total).clamp(0, 1).toDouble();
          }
        }

        const white = Colors.white;
        final dim = Colors.white.withValues(alpha: .88);

        return Material(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openItems(context),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(12)),
                        child: Icon(s.online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded, color: white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(kicker.toUpperCase(),
                                style: TextStyle(color: dim, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: .6)),
                            const SizedBox(height: 2),
                            Text(title, style: const TextStyle(color: white, fontSize: 17, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${s.pending}',
                                style: const TextStyle(color: white, fontSize: 44, height: 1, fontWeight: FontWeight.w800, letterSpacing: -1)),
                            const SizedBox(height: 2),
                            Text(late ? 'items not sent yet' : 'items waiting to send', style: TextStyle(color: dim, fontSize: 13)),
                          ],
                        ),
                      ),
                      if (s.syncAt != null && s.readyToday)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Send by', style: TextStyle(color: dim, fontSize: 12)),
                            Text(_time(s.syncAt!), style: const TextStyle(color: white, fontSize: 20, fontWeight: FontWeight.w800)),
                            Text(countdown, style: TextStyle(color: dim, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        )
                      else if (countdown.isNotEmpty)
                        Text(countdown, style: TextStyle(color: dim, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (s.syncAt != null && s.readyToday) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: .22),
                        valueColor: const AlwaysStoppedAnimation(white),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.generatedAt == null ? 'Today\'s data' : '${_time(s.generatedAt!)} data downloaded',
                            style: TextStyle(color: dim, fontSize: 11),
                          ),
                        ),
                        Text('Last class ends ${_time(s.syncAt!)}', style: TextStyle(color: dim, fontSize: 11)),
                      ],
                    ),
                  ],
                  if (s.needsReview > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(10)),
                      child: Row(
                        children: [
                          const Icon(Icons.report_problem_rounded, color: white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${s.needsReview} item(s) refused by the server - tap to see',
                                style: const TextStyle(color: white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: white,
                              foregroundColor: bg,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            onPressed: s.syncing ? null : () => OfflineSync.instance.run(forcePack: true),
                            icon: s.syncing
                                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: bg))
                                : const Icon(Icons.sync_rounded, size: 18),
                            label: Text(s.syncing ? 'Syncing...' : button),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 130,
                        child: Text(foot, style: TextStyle(color: dim, fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ================================================================ work */

class WorkAction {
  const WorkAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.sub = '',
    this.color = AppColors.primary,
    this.tint = AppColors.primaryLight,
    this.offline = false,
  });

  final String label;
  final String sub;
  final IconData icon;
  final Color color;
  final Color tint;
  final VoidCallback onTap;

  /// Works without internet (offline mode).
  final bool offline;
}

/// Big buttons for the work that also runs offline; small ones for the rest
/// (grey while offline).
class DashboardWorkGrid extends StatelessWidget {
  const DashboardWorkGrid({super.key, required this.main, required this.more, this.columns = 2});

  final List<WorkAction> main;
  final List<WorkAction> more;
  final int columns;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineStatus>(
      valueListenable: OfflineSync.instance.status,
      builder: (context, s, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Title('Work', note: 'Works offline'),
            if (main.isNotEmpty)
              GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [for (final a in main) _BigAction(action: a)],
              ),
            if (more.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in more)
                    _SmallAction(
                      action: a,
                      enabled: s.online || a.offline,
                    ),
                ],
              ),
            ],
            if (!s.online && more.any((a) => !a.offline)) ...[
              const SizedBox(height: 8),
              const Text(
                'Grey buttons need internet. They open again when the phone is online.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BigAction extends StatelessWidget {
  const _BigAction({required this.action});
  final WorkAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: _border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: action.tint, borderRadius: BorderRadius.circular(12)),
                    child: Icon(action.icon, color: action.color, size: 22),
                  ),
                  const Spacer(),
                  if (action.offline)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(99)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_off_rounded, size: 12, color: Color(0xFF334155)),
                          SizedBox(width: 4),
                          Text('OK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                        ],
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  if (action.sub.isNotEmpty)
                    Text(action.sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({required this.action, required this.enabled});
  final WorkAction action;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? Colors.white : _border,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: _border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled
            ? action.onTap
            : () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${action.label} needs internet.')),
                ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 16, color: enabled ? action.color : const Color(0xFF64748B)),
              const SizedBox(width: 6),
              Text(action.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: enabled ? AppColors.textPrimary : const Color(0xFF475569),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/* =============================================================== today */

/// Today: from the server while online (all phones), from this phone offline.
class TodayTiles extends StatelessWidget {
  const TodayTiles({
    super.key,
    this.serverAttendance,
    this.serverCollected,
    this.serverMine,
    this.serverClasses,
    this.onTapPayments,
  });

  /// null = no fresh server numbers (offline / old saved dashboard)
  final int? serverAttendance;
  final double? serverCollected;
  final double? serverMine;
  final int? serverClasses;
  final VoidCallback? onTapPayments;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineStatus>(
      valueListenable: OfflineSync.instance.status,
      builder: (context, s, _) {
        final server = s.online && serverAttendance != null;
        final phone = AppColors.primary;

        final tiles = server
            ? [
                ('Attendance', '$serverAttendance', s.phoneAttendance > 0 ? '${s.phoneAttendance} offline' : 'all phones', AppColors.textSecondary),
                ('Collected', _money(serverCollected ?? 0), serverMine != null ? 'you: ${_money(serverMine!)}' : 'all phones', AppColors.successText),
                ('Classes', '${serverClasses ?? s.classCount}', 'today', AppColors.textSecondary),
              ]
            : [
                ('Attendance', '+${s.phoneAttendance}', 'on this phone', phone),
                ('Collected', _money(s.phoneTotal), '${s.phonePayments} on this phone', phone),
                ('New students', '+${s.phoneStudents}', 'on this phone', phone),
              ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Title('Today', note: server ? 'From the server' : 'Saved on this phone'),
            Row(
              children: [
                for (var i = 0; i < tiles.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: i == 1 ? onTapPayments : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tiles[i].$1, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(tiles[i].$2,
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                              ),
                              const SizedBox(height: 4),
                              Text(tiles[i].$3,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tiles[i].$4)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }
}

/* =============================================================== queue */

/// The newest items saved on this phone (waiting / refused first).
class PhoneQueuePreview extends StatelessWidget {
  const PhoneQueuePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineStatus>(
      valueListenable: OfflineSync.instance.status,
      builder: (context, s, _) {
        // nothing ever saved offline (normal online day): keep the dashboard short
        if (s.recent.isEmpty && s.online) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Title('Saved on this phone', action: 'See all', onAction: () => _openItems(context)),
                if (s.pending == 0 && s.needsReview == 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.successLight.withValues(alpha: .6), borderRadius: BorderRadius.circular(12)),
                    child: const Row(
                      children: [
                        Icon(Icons.check_rounded, color: AppColors.successText, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text('Everything is on the server. Nothing waiting.',
                              style: TextStyle(color: AppColors.successText, fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                for (final q in s.recent) _QueueRow(item: q),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final (String tag, Color color, Color tint) = switch (item['type']) {
      'payment' => ('PAY', AppColors.successText, AppColors.successLight),
      'student' => ('NEW', AppColors.violet, AppColors.violetLight),
      'enrollment' => ('CLS', AppColors.warningText, AppColors.warningLight),
      _ => ('ATT', AppColors.primary, AppColors.primaryLight),
    };
    final (String label, Color fg, Color bg) = switch (item['_status']) {
      'synced' => ('Sent', AppColors.successText, AppColors.successLight),
      'conflict' => ('Conflict', const Color(0xFF9A3412), const Color(0xFFFFEDD5)),
      'failed' => ('Refused', AppColors.dangerText, AppColors.dangerLight),
      _ => ('Waiting', AppColors.primary, const Color(0xFFDBEAFE)),
    };
    final at = DateTime.tryParse(item['happened_at']?.toString() ?? '')?.toLocal();
    final sub = [
      if (item['receipt_number'] != null) item['receipt_number'].toString(),
      if (at != null) _time(at),
      if (item['_status'] == 'conflict' || item['_status'] == 'failed')
        if (item['_message'] != null) item['_message'].toString(),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      margin: const EdgeInsets.only(right: 8),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: _soft))),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(10)),
            child: Text(tag, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['_label']?.toString() ?? item['type'].toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (sub.isNotEmpty)
                  Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
            child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/* ============================================================= classes */

/// Today's classes from the day's offline data, with the scan window now
/// (used while offline; online the server's list is shown).
class OfflineClassesList extends StatelessWidget {
  const OfflineClassesList({super.key, this.showBranch = false});
  final bool showBranch;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineStatus>(
      valueListenable: OfflineSync.instance.status,
      builder: (context, s, _) {
        final classes = s.readyToday ? s.schedules : const <Map<String, dynamic>>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Title("Today's classes", note: classes.isEmpty ? null : '${classes.length} classes'),
            if (classes.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                child: Text(
                  s.readyToday ? 'No classes today.' : 'Today\'s classes are shown after today\'s data is downloaded.',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            for (final c in classes) ...[
              _ClassRow(item: c, phoneCount: s.attendanceBySchedule[int.tryParse(c['id']?.toString() ?? '') ?? 0] ?? 0, showBranch: showBranch),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.item, required this.phoneCount, required this.showBranch});
  final Map<String, dynamic> item;
  final int phoneCount;
  final bool showBranch;

  @override
  Widget build(BuildContext context) {
    DateTime? at(String key) => DateTime.tryParse(item[key]?.toString() ?? '')?.toLocal();
    final now = DateTime.now();
    final start = at('start_at');
    final end = at('end_at');
    final from = at('scan_from');
    final until = at('scan_until');

    final (String label, Color fg, Color bg, Color border) = (from != null && until != null && !now.isBefore(from) && !now.isAfter(until))
        ? ('Scan open now', AppColors.successText, AppColors.successLight, AppColors.success)
        : (from != null && now.isBefore(from))
            ? ('Scan opens ${_time(from)}', const Color(0xFF92400E), AppColors.warningLight, _border)
            : ('Ended', const Color(0xFF334155), _soft, _border);

    final branch = item['branch'] is Map ? (item['branch'] as Map)['name']?.toString() : null;
    final meta = [
      item['teacher_name'] ?? item['teacher'],
      item['hall'],
      if (item['category'] != null) item['category'],
      if (showBranch && branch != null) branch,
    ].where((v) => v != null && v.toString().isNotEmpty).join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(start == null ? '-' : _time(start), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                Text(end == null ? '' : _time(end), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['class_name']?.toString() ?? '',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                if (meta.isNotEmpty) Text(meta, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99)),
                      child: Text(label, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                    if (phoneCount > 0)
                      Text('+$phoneCount on this phone',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "As of 8:05 AM" note for numbers from the dashboard saved on the phone.
String asOfNote(DateTime cachedAt) {
  final now = DateTime.now();
  final sameDay = cachedAt.year == now.year && cachedAt.month == now.month && cachedAt.day == now.day;
  return 'As of ${sameDay ? '' : '${DateFormat('d MMM').format(cachedAt)} '}${_time(cachedAt)}';
}
