import 'package:flutter/material.dart';

import '../../../../../core/storage/session_storage.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../auth/data/models/branch_model.dart';

/// Branch dropdown for student registration.
///
/// - Branches come from the login session (only the user's own branches).
/// - One branch      -> picked automatically, shown read-only.
/// - Many branches   -> dropdown; starts with the branch picked on the
///                      dashboard (if any), otherwise the user must choose.
/// - [lockedBranchId] -> permanent card: the card's branch is used and
///                      cannot be changed (the server only accepts it).
class BranchSelectorField extends StatefulWidget {
  final int? lockedBranchId;
  final String? lockedBranchName;
  final ValueChanged<int?> onChanged;
  final bool enabled;

  const BranchSelectorField({
    super.key,
    required this.onChanged,
    this.lockedBranchId,
    this.lockedBranchName,
    this.enabled = true,
  });

  @override
  State<BranchSelectorField> createState() => _BranchSelectorFieldState();
}

class _BranchSelectorFieldState extends State<BranchSelectorField> {
  List<BranchModel> _branches = const [];
  int? _selectedId;
  bool _loading = true;

  bool get _isLocked => widget.lockedBranchId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final branches = await SessionStorage.getBranches();
    final dashboardBranchId = await SessionStorage.getSelectedBranchId();

    int? selected;

    if (_isLocked) {
      selected = widget.lockedBranchId;
    } else if (branches.length == 1) {
      selected = branches.first.id;
    } else if (dashboardBranchId != null &&
        branches.any((b) => b.id == dashboardBranchId)) {
      selected = dashboardBranchId;
    }

    if (!mounted) return;

    setState(() {
      _branches = branches;
      _selectedId = selected;
      _loading = false;
    });

    // Tell the page which branch is in use from the start
    widget.onChanged(selected);
  }

  String? _nameOf(int? id) {
    if (id == null) return null;
    for (final b in _branches) {
      if (b.id == id) return b.code == null ? b.name : '${b.name} (${b.code})';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(minHeight: 2),
      );
    }

    // Card branch, or the user's only branch -> read-only
    if (_isLocked || _branches.length == 1) {
      final name = _isLocked
          ? (widget.lockedBranchName ?? _nameOf(widget.lockedBranchId) ?? 'Card branch')
          : _nameOf(_selectedId) ?? '-';

      return InputDecorator(
        decoration: _decoration(
          helper: _isLocked ? 'This card belongs to this branch' : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            ),
            const Icon(Icons.lock_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      );
    }

    if (_branches.isEmpty) {
      return InputDecorator(
        decoration: _decoration(
          error: 'No branch found. Please logout and login again.',
        ),
        child: const Text('-'),
      );
    }

    return DropdownButtonFormField<int>(
      value: _selectedId,
      isExpanded: true,
      decoration: _decoration(),
      hint: const Text('Select branch'),
      items: _branches
          .map(
            (b) => DropdownMenuItem<int>(
              value: b.id,
              child: Text(
                b.code == null ? b.name : '${b.name} (${b.code})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: widget.enabled
          ? (value) {
              setState(() => _selectedId = value);
              widget.onChanged(value);
            }
          : null,
      validator: (value) => value == null ? 'Please select a branch' : null,
    );
  }

  InputDecoration _decoration({String? helper, String? error}) {
    return InputDecoration(
      labelText: 'Branch',
      helperText: helper,
      errorText: error,
      filled: true,
      fillColor: AppColors.background,
      prefixIcon: const Icon(Icons.store_mall_directory_rounded),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    );
  }
}
