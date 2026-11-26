import 'package:flutter/material.dart';

import 'offline_sync.dart';

/// Offline mode at a glance: ready for today?, waiting to send, to check.
/// Tap: the list of offline items on this phone; the button syncs now.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<OfflineStatus>(
      valueListenable: OfflineSync.instance.status,
      builder: (context, s, _) {
        final late = s.pending > 0 && s.syncAt != null && DateTime.now().isAfter(s.syncAt!);

        final Color color;
        final IconData icon;
        final String title;
        String subtitle;

        if (s.needsReview > 0) {
          color = Colors.orange.shade800;
          icon = Icons.report_problem_rounded;
          title = '${s.needsReview} offline item(s) refused - tap to see';
        } else if (late) {
          color = Colors.red.shade700;
          icon = Icons.cloud_off_rounded;
          title = '${s.pending} item(s) not sent - connect to the internet';
        } else if (s.pending > 0) {
          color = Colors.blue.shade700;
          icon = Icons.cloud_upload_rounded;
          title = '${s.pending} item(s) waiting to be sent';
        } else if (!s.online) {
          color = Colors.grey.shade800;
          icon = Icons.cloud_off_rounded;
          title = s.readyToday ? 'Offline - attendance and payments still work' : 'Offline - today\'s data not downloaded';
        } else {
          color = Colors.green.shade700;
          icon = Icons.cloud_done_rounded;
          title = s.readyToday ? 'Offline ready for today' : 'Downloading today\'s offline data...';
        }

        subtitle = s.readyToday ? '${s.classCount} class(es) today' : 'Connect once a day to download today\'s classes';
        if (s.syncAt != null && s.readyToday) {
          subtitle += ' - send by ${_time(s.syncAt!)}';
        }
        if (s.lastSync != null) {
          subtitle += ' - synced ${_time(s.lastSync!)}';
        }

        return Material(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OfflineItemsPage())),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  s.syncing
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          tooltip: 'Sync now',
                          icon: Icon(Icons.sync_rounded, color: color),
                          onPressed: () => OfflineSync.instance.run(forcePack: true),
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String _time(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }
}

/// Attendance and payments recorded offline on this phone (last 3 days).
class OfflineItemsPage extends StatefulWidget {
  const OfflineItemsPage({super.key});

  @override
  State<OfflineItemsPage> createState() => _OfflineItemsPageState();
}

class _OfflineItemsPageState extends State<OfflineItemsPage> {
  late Future<List<Map<String, dynamic>>> _items;

  @override
  void initState() {
    super.initState();
    _items = OfflineSync.instance.items();
  }

  Future<void> _sync() async {
    await OfflineSync.instance.run();
    if (!mounted) return;
    setState(() => _items = OfflineSync.instance.items());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline items'),
        actions: [IconButton(onPressed: _sync, icon: const Icon(Icons.sync_rounded), tooltip: 'Sync now')],
      ),
      body: Column(
        children: [
          const Padding(padding: EdgeInsets.all(12), child: OfflineBanner()),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _items,
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final items = snap.data!;
                if (items.isEmpty) {
                  return const Center(child: Text('Nothing recorded offline.'));
                }
                return ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _tile(items[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(Map<String, dynamic> q) {
    final status = q['_status']?.toString() ?? 'pending';
    final (Color color, String label) = switch (status) {
      'synced' => (Colors.green.shade700, 'Sent'),
      'conflict' => (Colors.orange.shade800, 'Conflict'),
      'failed' => (Colors.red.shade700, 'Refused'),
      _ => (Colors.blue.shade700, 'Waiting'),
    };
    final time = DateTime.tryParse(q['happened_at']?.toString() ?? '')?.toLocal();
    final receipt = q['receipt_number']?.toString();

    return ListTile(
      leading: Icon(q['type'] == 'payment' ? Icons.payments_rounded : Icons.how_to_reg_rounded, color: color),
      title: Text(q['_label']?.toString() ?? q['type'].toString()),
      subtitle: Text([
        if (time != null) '${time.day}/${time.month} ${OfflineBanner._time(time)}',
        if (receipt != null) receipt,
        if (q['_message'] != null && status != 'synced') q['_message'].toString(),
      ].join(' - ')),
      trailing: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}
