import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/storage/session_storage.dart';

/// Calls /api/teacher-advances (Admin / Branch Admin). Only paying an
/// advance: listing / deleting / salary payment stay on the web.
class TeacherAdvanceApi {
  const TeacherAdvanceApi();

  static const String _base = '${ApiConstants.apiUrl}/teacher-advances';

  /// This month's teachers of the branch. Without [branchId] the server uses
  /// the user's only branch, or answers [TeacherAdvanceBranchChoice].
  Future<TeacherAdvanceList> teachers({int? branchId}) async {
    final query = branchId == null ? '' : '?branch_id=$branchId';
    final body = await _send(() async => http.get(
          Uri.parse('$_base/teachers$query'),
          headers: ApiConstants.headers(token: await SessionStorage.getToken()),
        ));

    return TeacherAdvanceList.fromJson(_map(body['data']));
  }

  Future<TeacherAdvanceSlip> pay({
    required int teacherId,
    required int branchId,
    required double amount,
    String? reason,
    String? note,
  }) async {
    final body = await _send(() async => http.post(
          Uri.parse(_base),
          headers: ApiConstants.headers(token: await SessionStorage.getToken()),
          body: jsonEncode({
            'teacher_id': teacherId,
            'branch_id': branchId,
            'amount': amount,
            if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          }),
        ));

    return TeacherAdvanceSlip.fromJson(_map(body['data']));
  }

  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    final http.Response response;

    try {
      response = await call();
    } on http.ClientException catch (e) {
      throw TeacherAdvanceException(e.message);
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(response.body);
      body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    } on FormatException {
      throw const TeacherAdvanceException('The server sent an unexpected response. Please try again.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }

    final message = body['message']?.toString() ?? '';

    // 422 "Select a branch." with the user's branches
    final branches = _map(body['data'])['branches'];
    if (response.statusCode == 422 && branches is List) {
      throw TeacherAdvanceBranchChoice(
        branches
            .whereType<Map<String, dynamic>>()
            .map((b) => TeacherAdvanceBranch(id: _int(b['id']), name: b['name']?.toString() ?? ''))
            .toList(),
      );
    }

    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) {
        throw TeacherAdvanceException(first.first.toString(), statusCode: response.statusCode);
      }
    }

    if (response.statusCode == 403) {
      throw TeacherAdvanceException(
        message.isNotEmpty ? message : 'Only Admin and Branch Admin can pay teacher advances.',
        statusCode: 403,
      );
    }

    if (response.statusCode == 404) {
      throw const TeacherAdvanceException(
        'Teacher advance is not on this server yet. The server needs an update.',
        statusCode: 404,
      );
    }

    throw TeacherAdvanceException(
      message.isNotEmpty ? message : 'Something went wrong. Please try again.',
      statusCode: response.statusCode,
    );
  }
}

/* -------------------------------- Models -------------------------------- */

class TeacherAdvanceBranch {
  final int id;
  final String name;

  const TeacherAdvanceBranch({required this.id, required this.name});
}

class TeacherAdvanceTeacher {
  final int id;
  final String customId;
  final String name;
  final double gross;
  final double advance;
  final double deductions;
  final bool salaryPaid;
  final double available;

  const TeacherAdvanceTeacher({
    required this.id,
    required this.customId,
    required this.name,
    required this.gross,
    required this.advance,
    required this.deductions,
    required this.salaryPaid,
    required this.available,
  });

  factory TeacherAdvanceTeacher.fromJson(Map<String, dynamic> json) => TeacherAdvanceTeacher(
        id: _int(json['id']),
        customId: json['custom_id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        gross: _double(json['gross']),
        advance: _double(json['advance']),
        deductions: _double(json['deductions']),
        salaryPaid: json['salary_paid'] == true,
        available: _double(json['available']),
      );
}

class TeacherAdvanceList {
  final TeacherAdvanceBranch branch;
  final String month;
  final List<TeacherAdvanceTeacher> teachers;

  const TeacherAdvanceList({required this.branch, required this.month, required this.teachers});

  factory TeacherAdvanceList.fromJson(Map<String, dynamic> json) {
    final branch = _map(json['branch']);
    final teachers = json['teachers'];

    return TeacherAdvanceList(
      branch: TeacherAdvanceBranch(id: _int(branch['id']), name: branch['name']?.toString() ?? ''),
      month: json['month']?.toString() ?? '',
      teachers: teachers is List
          ? teachers.whereType<Map<String, dynamic>>().map(TeacherAdvanceTeacher.fromJson).toList()
          : const [],
    );
  }
}

/// What the server saved: shown and printed on the slip.
class TeacherAdvanceSlip {
  final int id;
  final String reference;
  final String teacherName;
  final String teacherCustomId;
  final String branchName;
  final double amount;
  final String? reason;
  final String? note;
  final String date;
  final String time;
  final String month;
  final String? paidBy;
  final double monthAdvanceTotal;
  final double availableAfter;

  const TeacherAdvanceSlip({
    required this.id,
    required this.reference,
    required this.teacherName,
    required this.teacherCustomId,
    required this.branchName,
    required this.amount,
    required this.reason,
    required this.note,
    required this.date,
    required this.time,
    required this.month,
    required this.paidBy,
    required this.monthAdvanceTotal,
    required this.availableAfter,
  });

  factory TeacherAdvanceSlip.fromJson(Map<String, dynamic> json) {
    final teacher = _map(json['teacher']);

    String? text(dynamic value) {
      final s = value?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    return TeacherAdvanceSlip(
      id: _int(json['id']),
      reference: json['reference']?.toString() ?? '',
      teacherName: teacher['name']?.toString() ?? '',
      teacherCustomId: teacher['custom_id']?.toString() ?? '',
      branchName: _map(json['branch'])['name']?.toString() ?? '',
      amount: _double(json['amount']),
      reason: text(json['reason']),
      note: text(json['note']),
      date: json['date']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      month: json['month']?.toString() ?? '',
      paidBy: text(json['paid_by']),
      monthAdvanceTotal: _double(json['month_advance_total']),
      availableAfter: _double(json['available_after']),
    );
  }
}

class TeacherAdvanceException implements Exception {
  final String message;
  final int? statusCode;

  const TeacherAdvanceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// The user has several branches: pick one first.
class TeacherAdvanceBranchChoice implements Exception {
  final List<TeacherAdvanceBranch> branches;

  const TeacherAdvanceBranchChoice(this.branches);

  @override
  String toString() => 'Select a branch.';
}

Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic> ? value : <String, dynamic>{};

int _int(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

double _double(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
