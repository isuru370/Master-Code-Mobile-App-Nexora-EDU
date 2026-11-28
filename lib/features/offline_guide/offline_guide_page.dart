import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Offline mode guide for staff, in Sinhala. Everything is in the app, so it
/// opens without internet too.
class OfflineGuidePage extends StatelessWidget {
  const OfflineGuidePage({super.key});

  static const routeName = '/offline-guide';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Offline Guide')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: const [
          _Intro(),
          SizedBox(height: 16),
          _Section(
            number: 1,
            icon: Icons.wb_sunny_rounded,
            color: AppColors.primary,
            title: 'හැම දවසෙම උදේ',
            steps: [
              'App එක open කරලා internet එකට සම්බන්ධ වෙන්න (Wi-Fi හෝ mobile data).',
              'Dashboard එකේ උඩ card එකේ "Online · ready for today" කියලා එනකම් ඉන්න. ඒ කියන්නේ අද classes සහ ළමයින්ගේ විස්තර phone එකට ආවා.',
              'එහෙම ආවට පස්සේ internet නැති වුණත් වැඩ කරන්න පුළුවන්.',
            ],
            tip: 'අද data download වෙලා නැත්නම් offline වැඩ කරන්න බෑ. ඒ නිසා දවසට එක පාරක්වත් internet එකට සම්බන්ධ වෙන්න ඕනේ.',
          ),
          _Section(
            number: 2,
            icon: Icons.cloud_off_rounded,
            color: AppColors.successText,
            title: 'Internet නැතුව කරන්න පුළුවන් දේවල්',
            steps: [
              'Attendance: අද class වල, scan කරන්න පුළුවන් වෙලාව ඇතුළත.',
              'Payment: ළමයාගේ ඕනෑම class එකක fee එක. Receipt එකට OF-XXXX-0001 වගේ offline අංකයක් වැටෙනවා.',
              'Register: අලුත් ළමයෙක් register කිරීම (admission fee එකත් එක්ක).',
              'Add Class: ළමයෙක් class එකකට add කිරීම.',
            ],
            tip: 'Admission page, Tute, Today Payments, Courses, Teacher Advance වගේ අනිත් දේවල් වලට internet ඕනේ. Offline වෙලාවට ඒ buttons අළු පාට වෙනවා.',
          ),
          _Section(
            number: 3,
            icon: Icons.touch_app_rounded,
            color: AppColors.violet,
            title: 'Offline කරන හැටි',
            steps: [
              'Attendance / Payment: සාමාන්‍ය විදියටම card එක scan කරන්න. "saved on this phone (offline)" කියලා message එකක් එනවා.',
              'Register (temporary card): "Different card" කොටුවේ ළමයාට දෙන card එකේ අංකය (TMP අංකය) අනිවාර්යයෙන්ම type කරන්න.',
              'Register (permanent card): card එක scan කරලා සාමාන්‍ය විදියටම form එක fill කරන්න.',
              'Photo: සාමාන්‍ය විදියටම ගන්න. ඒක phone එකේ තියාගෙන ළමයා server එකට ගියාම upload වෙනවා.',
              'Custom ID එක හැදෙන්නේ server එකේ. Offline register කළාම "After sync" කියලා පෙන්නනවා.',
            ],
          ),
          _ColorsSection(),
          _Section(
            number: 5,
            icon: Icons.report_problem_rounded,
            color: Color(0xFF9A3412),
            title: 'Conflict / Refused ආවොත්',
            steps: [
              'Conflict: offline ගත්ත දෙයක් අතරතුර වෙන තැනකින් කරලා. උදා: එකම මාසෙ fee එක වෙන phone එකකින් හෝ web එකෙන් ගෙවලා.',
              'Refused: rule එකකට අනුව server එක ගත්තේ නෑ. උදා: class එක ළමයාගේ class එකක් නෙවෙයි.',
              'මේ දෙකම Admin ට web එකේ Finance → Offline Sync page එකේ පෙනෙනවා. Admin check කරලා හදනවා.',
              'Phone එකේ dashboard card එක ඔබලා "Offline items" list එකෙන් මොකක්ද වුණේ කියලා බලන්න පුළුවන්.',
            ],
            tip: 'Conflict එකක් ආවොත් ළමයාගෙන් ආයෙත් සල්ලි ගන්න එපා. Admin ට කියන්න.',
          ),
          _Section(
            number: 6,
            icon: Icons.block_rounded,
            color: AppColors.dangerText,
            title: 'කරන්න එපා',
            steps: [
              'යවන්න ඉතුරු items තියෙද්දී logout වෙන්න එපා. (App එකත් ඒකට ඉඩ දෙන්නේ නෑ.)',
              'App එක uninstall කරන්න හෝ app data clear කරන්න එපා. යවලා නැති items නැති වෙනවා.',
              'Phone එකේ දිනය / වෙලාව වෙනස් කරන්න එපා. Attendance සහ payment save වෙන්නේ phone එකේ වෙලාවට.',
              'එකම ළමයාගේ එකම මාසෙ fee එක phone දෙකකින් ගන්න එපා.',
            ],
          ),
          _Section(
            number: 7,
            icon: Icons.dns_rounded,
            color: AppColors.warningText,
            title: 'Server එක down වුණොත්',
            steps: [
              'Phone එකේ internet තියෙද්දිත් dashboard card එක තැඹිලි පාට වෙලා "Server down" කියලා එනවා නම්, ප්‍රශ්නය තියෙන්නේ server එකේ.',
              'බය වෙන්න එපා. Offline වගේම attendance, payment, register, add class කරන්න.',
              'Server එක ආපු ගමන් save කරපු ඒවා auto යනවා. App එක open කරලා තියන්න.',
              'පැයකට වඩා server එක down නම් Admin ට / Nexora support එකට කියන්න.',
            ],
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 32),
          SizedBox(height: 10),
          Text('Internet නැතුව වැඩ කරන හැටි',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
          SizedBox(height: 6),
          Text(
            'Internet නැති වුණත්, server එක down වුණත් attendance, payments, register සහ add class කරන්න පුළුවන්. '
            'ඒවා phone එකේ save වෙලා internet ආපු ගමන් server එකට auto යනවා.',
            style: TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.number,
    required this.icon,
    required this.color,
    required this.title,
    required this.steps,
    this.tip,
  });

  final int number;
  final IconData icon;
  final Color color;
  final String title;
  final List<String> steps;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('$number. $title',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 1),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: Text('${i + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(steps[i], style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
          if (tip != null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_rounded, size: 18, color: AppColors.warningText),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(tip!, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFF78350F))),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 4. The colours of the dashboard sync card.
class _ColorsSection extends StatelessWidget {
  const _ColorsSection();

  @override
  Widget build(BuildContext context) {
    const rows = [
      (AppColors.successText, 'කොළ', 'Online. සියල්ල server එකේ. ප්‍රශ්නයක් නෑ.'),
      (AppColors.darkLight, 'අළු', 'Internet නෑ. Offline වැඩ කරන්න. Items phone එකේ save වෙනවා.'),
      (AppColors.warningText, 'තැඹිලි', 'Internet තියෙනවා, server එක down. Offline වගේම වැඩ කරන්න.'),
      (AppColors.dangerText, 'රතු', '"Send by" වෙලාව පහු වුණා, items තාම යවලා නෑ. ඉක්මනට internet එකට සම්බන්ධ වෙන්න.'),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.palette_rounded, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('4. Dashboard card එකේ පාටවල්',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: r.$1, borderRadius: BorderRadius.circular(8)),
                    child: Text(r.$2, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(r.$3, style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.textPrimary))),
                ],
              ),
            ),
          const SizedBox(height: 4),
          const Text(
            '"Send by" කියන්නේ අද අන්තිම class එක ඉවර වෙන වෙලාව. ඒ වෙලාවට කලින් save කරපු ඔක්කොම server එකට යවන්න ඕනේ. '
            'Card එකේ ලොකු අංකය කියන්නේ තාම යවන්න ඉතුරු items ගාණ.',
            style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
