import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:month_year_picker/month_year_picker.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/printer_service.dart';
import '../../../qr/data/model/scan_payment_new/scan_payment_response_model.dart';
import '../../data/models/mark_payment_item_model.dart';
import '../../data/models/mark_payment_request_model.dart';
import '../../data/models/mark_payment_response_model.dart';
import '../../data/payment_month_info.dart';
import '../bloc/mark_payment/mark_payment_bloc.dart';
import 'utils/payment_receipt_print.dart';
import '../../../../../core/institute/institute_info.dart';

class PaymentPage extends StatefulWidget {
  final String? markMethod;
  final ScanPaymentResponseModel paymentResponse;

  const PaymentPage({
    super.key,
    required this.paymentResponse,
    this.markMethod,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final PrinterService _printerService = PrinterService();

  final Set<int> _selectedEnrollmentIds = <int>{};

  DateTime _selectedPaymentDate = DateTime.now();

  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final student = widget.paymentResponse.student;
    final classes = widget.paymentResponse.classes;

    if (student == null) {
      return const Scaffold(body: Center(child: Text('No student data found')));
    }

    return BlocListener<MarkPaymentBloc, MarkPaymentState>(
      listener: (context, state) async {
        if (!mounted) return;

        if (state is MarkPaymentLoading) {
          setState(() {
            _isSubmitting = true;
          });
        } else if (state is MarkPaymentLoaded) {
          final response = state.response;

          // ============================================================
          // PRINT BACKEND RECEIPT
          // ============================================================

          try {
            await _printBulkReceipt(paymentResponse: response);
          } catch (e) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.warning,
                content: Text('Receipt print failed: $e'),
              ),
            );
          }

          setState(() {
            _isSubmitting = false;
            _selectedEnrollmentIds.clear();
          });

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text('Payments saved successfully'),
            ),
          );

          Future.delayed(const Duration(milliseconds: 900), () {
            if (!mounted) return;

            Navigator.pop(context);
          });
        } else if (state is MarkPaymentError) {
          setState(() {
            _isSubmitting = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.danger, content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,

        appBar: AppBar(
          title: const Text(
            'Student Payments',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),

        body: SafeArea(
          child: Column(
            children: [
              // ============================================================
              // STUDENT HEADER
              // ============================================================
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.largeShadow,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.white,

                      backgroundImage: student.imageUrl.isNotEmpty
                          ? NetworkImage(student.imageUrl)
                          : null,

                      child: student.imageUrl.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              size: 32,
                              color: AppColors.primary,
                            )
                          : null,
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.initialName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Student ID: ${student.customId}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Mobile: ${student.guardianMobile}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ============================================================
              // CLASSES
              // ============================================================
              Expanded(
                child: classes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.payments_outlined,
                              size: 80,
                              color: AppColors.textMuted,
                            ),

                            const SizedBox(height: 14),

                            Text(
                              'No Classes Available',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.darkLight,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'This student has no active class enrollments.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: classes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final payment = classes[index];

                          final latestPayment = payment.lastPayment;

                          final isSelected = _selectedEnrollmentIds.contains(
                            payment.enrollmentId,
                          );

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: AppColors.softShadow,
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: payment.isFreeCard
                                  ? null
                                  : () {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedEnrollmentIds.remove(
                                            payment.enrollmentId,
                                          );
                                        } else {
                                          _selectedEnrollmentIds.add(
                                            payment.enrollmentId!,
                                          );
                                        }
                                      });
                                    },
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // ==================================================
                                    // CLASS TITLE
                                    // ==================================================
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  payment.className,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.dark,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                        Checkbox(
                                          value: isSelected,
                                          activeColor: AppColors.primary,
                                          visualDensity: VisualDensity.compact,
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
                                          ),
                                          onChanged: payment.isFreeCard
                                              ? null
                                              : (value) {
                                                  setState(() {
                                                    if (value == true) {
                                                      _selectedEnrollmentIds
                                                          .add(
                                                            payment
                                                                .enrollmentId!,
                                                          );
                                                    } else {
                                                      _selectedEnrollmentIds
                                                          .remove(
                                                            payment
                                                                .enrollmentId,
                                                          );
                                                    }
                                                  });
                                                },
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 16),

                                    // ==================================================
                                    // BADGES
                                    // ==================================================
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: [
                                        _premiumBadge(
                                          icon: Icons.category_rounded,
                                          text: payment.categoryName,
                                          color: AppColors.warning,
                                        ),

                                        _premiumBadge(
                                          icon: Icons.school_rounded,
                                          text: 'Grade ${payment.grade}',
                                          color: AppColors.violet,
                                        ),

                                        _premiumBadge(
                                          icon: Icons.payments_rounded,
                                          text: payment.isFreeCard
                                              ? 'Free Card'
                                              : 'LKR ${_formatAmount(payment.finalFee)}',
                                          color: AppColors.primary,
                                        ),

                                        _premiumBadge(
                                          icon: Icons.person_rounded,
                                          text: payment.teacherInitials,
                                          color: AppColors.success,
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 12),

                                    // ==================================================
                                    // PAYMENT STATUS
                                    // ==================================================
                                    if (!payment.isFreeCard)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xfff8fafc),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: AppColors.border,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // ==========================================================
                                            // PAYMENT STATUS HEADER
                                            // ==========================================================
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.receipt_long_rounded,
                                                  size: 18,
                                                ),

                                                const SizedBox(width: 8),

                                                const Expanded(
                                                  child: Text(
                                                    'Payment Status',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),

                                                _paymentStatusBadge(
                                                  _getCurrentMonthPaymentStatus(
                                                    payment,
                                                  ),
                                                ),
                                              ],
                                            ),

                                            // ==========================================================
                                            // LATEST PAYMENT
                                            // ==========================================================
                                            if (latestPayment != null) ...[
                                              const SizedBox(height: 8),

                                              const Divider(height: 1),

                                              const SizedBox(height: 10),

                                              Row(
                                                children: [
                                                  // AMOUNT
                                                  Expanded(
                                                    child: _paymentInfoItem(
                                                      title: 'Amount',
                                                      value:
                                                          'LKR ${_formatAmount(latestPayment.amount)}',
                                                      icon: Icons
                                                          .payments_rounded,
                                                    ),
                                                  ),

                                                  const SizedBox(width: 8),

                                                  // MONTH
                                                  Expanded(
                                                    child: _paymentInfoItem(
                                                      title: 'Month',
                                                      value:
                                                          _formatPaymentMonth(
                                                            latestPayment
                                                                .paymentMonth!,
                                                          ),
                                                      icon: Icons
                                                          .calendar_month_rounded,
                                                    ),
                                                  ),

                                                  const SizedBox(width: 8),

                                                  // METHOD
                                                  Expanded(
                                                    child: _paymentInfoItem(
                                                      title: 'Method',
                                                      value:
                                                          latestPayment
                                                              .paymentMethod
                                                              ?.toUpperCase() ??
                                                          '-',
                                                      icon: Icons
                                                          .account_balance_wallet_rounded,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ] else ...[
                                              const SizedBox(height: 10),

                                              Text(
                                                'No payments made yet.',
                                                style: TextStyle(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // ============================================================
              // PAY BUTTON
              // ============================================================
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                decoration: const BoxDecoration(color: Colors.white),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting || _selectedEnrollmentIds.isEmpty
                        ? null
                        : () => _showPayDialog(classes),
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.payments_rounded),
                    label: Text(
                      _isSubmitting
                          ? 'Processing...'
                          : 'Pay ${_selectedEnrollmentIds.length} Selected Class(es)',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================================================
  // DEFAULT PAYMENT MONTH
  // ==========================================================================

  DateTime _getDefaultPaymentMonth(List<dynamic> selectedPayments) {
    final payablePayments = selectedPayments
        .where((item) => item.isFreeCard == false)
        .toList();

    if (payablePayments.isEmpty) {
      return DateTime.now();
    }

    // Single class payment
    if (payablePayments.length == 1) {
      final payment = payablePayments.first;
      final lastPayment = payment.lastPayment;

      // No previous payment
      if (lastPayment == null) {
        return DateTime.now();
      }

      try {
        final paymentMonth = lastPayment.paymentMonth.toString();

        DateTime lastMonth;

        if (paymentMonth.length >= 7) {
          lastMonth = DateTime.parse('${paymentMonth.substring(0, 7)}-01');
        } else {
          lastMonth = DateTime.parse('$paymentMonth-01');
        }

        // Always select NEXT month
        return DateTime(lastMonth.year, lastMonth.month + 1, 1);
      } catch (e) {
        return DateTime.now();
      }
    }

    // Multiple classes selected
    // Current month as default
    return DateTime(DateTime.now().year, DateTime.now().month, 1);
  }

  // ==========================================================================
  // PAYMENT DIALOG
  // ==========================================================================

  Future<void> _showPayDialog(List<dynamic> classes) async {
    final selectedPayments = classes
        .where((item) => _selectedEnrollmentIds.contains(item.enrollmentId))
        .where((item) => item.isFreeCard == false)
        .toList();

    if (selectedPayments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one payable class'),
        ),
      );

      return;
    }

    DateTime tempSelectedDate = _getDefaultPaymentMonth(selectedPayments);

    // Payment Rules (per institute): attendance this month, fee after the
    // rules, amount the cashier can change, optional tute. Without rules the
    // amounts stay the class fees, as before.
    final studentCode = widget.paymentResponse.student?.customId ?? '';
    final infos = <int, PaymentMonthInfo?>{};
    final giveTute = <int, bool>{};
    final chosenOption = <int, int?>{};
    final amountControllers = <int, TextEditingController>{
      for (final payment in selectedPayments)
        payment.enrollmentId as int: TextEditingController(
          text: _formatAmount(payment.finalFee),
        ),
    };
    var dialogOpen = true;
    var infoStarted = false;
    var loadingInfo = false;

    double amountOf(int enrollmentId) =>
        double.tryParse(amountControllers[enrollmentId]?.text.trim() ?? '') ?? 0;

    Future<void> loadInfos(StateSetter setDialogState) async {
      final month = DateFormat('yyyy-MM').format(tempSelectedDate);
      setDialogState(() => loadingInfo = true);

      final results = await Future.wait(
        selectedPayments.map(
          (payment) => PaymentMonthInfo.fetch(
            code: studentCode,
            enrollmentId: payment.enrollmentId as int,
            paymentMonth: month,
          ),
        ),
      );

      // Month changed again while loading, or the dialog was closed
      if (!dialogOpen || month != DateFormat('yyyy-MM').format(tempSelectedDate)) {
        return;
      }

      setDialogState(() {
        for (var i = 0; i < selectedPayments.length; i++) {
          final payment = selectedPayments[i];
          final id = payment.enrollmentId as int;
          final info = results[i];

          infos[id] = info;
          giveTute[id] = false;

          // The student's own fee option first; the cashier can pick another
          final option = info != null && info.feeOptionEnabled ? info.studentOption : null;
          chosenOption[id] = option?.id;

          // No attendance this month (institute rule): no payment by default
          final amount = info != null && info.noAttendance
              ? 0
              : (option?.amount ?? payment.finalFee.toDouble());
          amountControllers[id]!.text = _formatAmount(amount);
        }
        loadingInfo = false;
      });
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (!infoStarted) {
              infoStarted = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => loadInfos(setDialogState),
              );
            }

            final total = selectedPayments.fold<double>(
              0,
              (sum, payment) => sum + amountOf(payment.enrollmentId as int),
            );

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              titlePadding: EdgeInsets.zero,
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

              title: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm Payment',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ========================================================
                    // SELECTED COUNT
                    // ========================================================
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.school,
                            size: 20,
                            color: AppColors.primary,
                          ),

                          const SizedBox(width: 8),

                          Text(
                            '${selectedPayments.length} class(es) selected',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ========================================================
                    // PAYMENT MONTH
                    // ========================================================
                    InkWell(
                      onTap: () async {
                        final picked = await showMonthYearPicker(
                          context: dialogContext,
                          initialDate: tempSelectedDate,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 365 * 5),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365 * 5),
                          ),
                        );

                        if (picked != null) {
                          setDialogState(() {
                            tempSelectedDate = picked;
                          });
                          loadInfos(setDialogState);
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Payment Month',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('yyyy-MM').format(tempSelectedDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const Icon(
                              Icons.arrow_drop_down,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ========================================================
                    // INFO
                    // ========================================================
                    if (selectedPayments.length == 1)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryLight),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.primary,
                              size: 18,
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: Text(
                                'Default month is based on last payment date. You can change it if needed.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warningLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.warningLight),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: AppColors.warningText,
                              size: 18,
                            ),

                            const SizedBox(width: 8),

                            Expanded(
                              child: Text(
                                'Multiple classes selected. Default month is current month. You can change it if needed.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.warningText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),

                    // ========================================================
                    // SELECTED CLASSES
                    // ========================================================
                    const Text(
                      'Selected Classes:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 6),

                    if (loadingInfo)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: LinearProgressIndicator(minHeight: 2),
                      ),

                    ...selectedPayments.map((payment) {
                      final id = payment.enrollmentId as int;
                      final info = infos[id];
                      final editable = info?.customAmount ?? false;
                      final options = info != null && info.feeOptionEnabled
                          ? info.feeOptions
                          : const <PaymentFeeOption>[];

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${payment.className} - ${payment.subject}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.darkLight,
                                    ),
                                  ),
                                ),
                                if (!editable)
                                  Text(
                                    'LKR ${_formatAmount(amountOf(id))}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),

                            if (info != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _monthInfoLine(info),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: info.noAttendance
                                      ? AppColors.textSecondary
                                      : AppColors.primary,
                                ),
                              ),
                            ],

                            if (info != null && info.alreadyPaid) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Already paid for ${info.monthName}'
                                '${info.paidReceipt != null ? ' (${info.paidReceipt})' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.dangerText,
                                ),
                              ),
                            ],

                            if (options.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                // new month = new list and selection
                                key: ValueKey('fee-option-$id-${info!.monthName}'),
                                initialValue: chosenOption[id],
                                isExpanded: true,
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Fee option for ${info.monthName}',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                items: options
                                    .map(
                                      (option) => DropdownMenuItem<int>(
                                        value: option.id,
                                        child: Text(
                                          '${option.label} - LKR ${_formatAmount(option.amount)}'
                                          '${option.isStudentOption ? ' (student)' : ''}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => setDialogState(() {
                                  chosenOption[id] = value;
                                  final picked = options.where((o) => o.id == value);
                                  if (picked.isNotEmpty) {
                                    amountControllers[id]!.text =
                                        _formatAmount(picked.first.amount);
                                  }
                                }),
                              ),
                            ],

                            if (editable) ...[
                              const SizedBox(height: 8),
                              TextField(
                                controller: amountControllers[id],
                                keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                onChanged: (_) => setDialogState(() {}),
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Amount (LKR)',
                                  helperText: info!.noAttendance
                                      ? 'No attendance this month. Leave 0 to skip.'
                                      : 'Fee LKR ${_formatAmount(info.grossFee)}. Less is saved as a discount.',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],

                            if (info != null && info.tuteEnabled)
                              CheckboxListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                value: info.tuteIssued ? true : (giveTute[id] ?? false),
                                onChanged: info.tuteIssued
                                    ? null
                                    : (value) => setDialogState(
                                          () => giveTute[id] = value ?? false,
                                        ),
                                title: Text(
                                  info.tuteIssued
                                      ? 'Tute already given${info.tuteIssuedAt != null ? ' (${info.tuteIssuedAt})' : ''}'
                                      : 'Give ${info.monthName} tute',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 12),

                    // ========================================================
                    // TOTAL
                    // ========================================================
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSecondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),

                          Text(
                            'LKR ${_formatAmount(total)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ============================================================
              // ACTIONS
              // ============================================================
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: _isSubmitting || loadingInfo
                      ? null
                      : () {
                          setState(() {
                            _selectedPaymentDate = tempSelectedDate;
                          });

                          final amounts = {
                            for (final payment in selectedPayments)
                              payment.enrollmentId as int:
                                  amountOf(payment.enrollmentId as int),
                          };
                          final tutes = Map<int, bool>.from(giveTute);
                          final feeOptions = Map<int, int?>.from(chosenOption);

                          Navigator.pop(dialogContext);

                          _submitBulkPayments(
                            classes,
                            amounts: amounts,
                            giveTute: tutes,
                            feeOptions: feeOptions,
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Pay Now'),
                ),
              ],
            );
          },
        );
      },
    );

    dialogOpen = false;

    // The dialog still rebuilds its fields during the closing animation, so
    // the controllers are disposed only after that has finished.
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      for (final controller in amountControllers.values) {
        controller.dispose();
      }
    });
  }

  /// "Attendance in November 2026: 1" (+ no attendance warning)
  String _monthInfoLine(PaymentMonthInfo info) {
    final attendance = 'Attendance in ${info.monthName}: ${info.attendanceCount}';

    return info.noAttendance
        ? '$attendance · No attendance: no payment is taken'
        : attendance;
  }

  Widget _paymentInfoItem({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 3),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SUBMIT BULK PAYMENTS
  // ==========================================================================

  void _submitBulkPayments(
    List<dynamic> classes, {
    Map<int, double> amounts = const {},
    Map<int, bool> giveTute = const {},
    Map<int, int?> feeOptions = const {},
  }) {
    final selectedPayments = classes
        .where((item) => _selectedEnrollmentIds.contains(item.enrollmentId))
        .where((item) => item.isFreeCard == false)
        // Payment Rules: a 0 amount (e.g. no fee this month) is not sent
        .where((item) => (amounts[item.enrollmentId] ?? item.finalFee.toDouble()) > 0)
        .toList();

    if (selectedPayments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nothing to pay: no class has an amount above 0'),
        ),
      );

      return;
    }

    final student = widget.paymentResponse.student;

    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student data not available')),
      );

      return;
    }

    final markMethod = widget.markMethod ?? 'manual_mobile';

    final paymentMonth = DateFormat('yyyy-MM').format(_selectedPaymentDate);

    /*
    |--------------------------------------------------------------------------
    | Payment Method
    |--------------------------------------------------------------------------
    |
    | Backend PaymentMarker defaults to cash when
    | payment_method is not supplied.
    |
    | So currently we use cash.
    |
    */

    const paymentMethod = 'cash';

    final request = MarkPaymentRequestModel(
      payments: selectedPayments.map((item) {
        final finalAmount = amounts[item.enrollmentId] ?? item.finalFee.toDouble();

        return MarkPaymentItemModel(
          code: student.customId,

          enrollmentId: item.enrollmentId,

          amount: finalAmount,

          discountAmount: 0,

          paymentMonth: paymentMonth,

          paidAt: DateTime.now(),

          paymentMethod: paymentMethod,

          markMethod: markMethod,

          giveTute: giveTute[item.enrollmentId] ?? false,

          feeOptionId: feeOptions[item.enrollmentId],

          note:
              'Student Name ${student.initialName} | '
              '${item.className} | '
              '${item.categoryName} | '
              'Fee Option ${item.feeOption?.label ?? '-'} | '
              'Teacher ${item.teacherInitials} | '
              'Mobile payment',
        );
      }).toList(),
    );

    context.read<MarkPaymentBloc>().add(
      MarkPaymentRequested(requestModel: request),
    );
  }

  // ==========================================================================
  // PRINT BULK RECEIPT
  // ==========================================================================

  Future<void> _printBulkReceipt({
    required MarkPaymentResponseModel paymentResponse,
  }) async {
    final receipt = paymentResponse.receipt;

    if (receipt.classes.isEmpty) {
      return;
    }

    final classes = receipt.classes.map((item) {
      return ReceiptClassDetail(
        className: item.className,
        grade: item.grade,
        teacherName: item.teacherName,
        categoryName: item.categoryName,
        feeOptionName: item.feeOptionName,
        classFee: item.classFee,
        receiptNumber: item.receiptNumber,
      );
    }).toList();

    await PaymentReceiptPrint.printReceipt(
      printerService: _printerService,
      instituteName: InstituteInfo.name,
      studentName: receipt.studentDetails.name,
      studentId: receipt.studentDetails.customId,
      paymentMonth: DateFormat('yyyy-MM').format(_selectedPaymentDate),
      paymentMethod: receipt.paymentMethod,
      classes: classes,
    );
  }

  /*
    |--------------------------------------------------------------------------
    | Fallback
    |--------------------------------------------------------------------------
    */
}

// ==========================================================================
// PAYMENT STATUS BADGE
// ==========================================================================

Widget _paymentStatusBadge(String status) {
  final normalized = status.toLowerCase();

  Color color;

  if (normalized == 'paid' ||
      normalized == 'completed' ||
      normalized == 'fully_paid') {
    color = AppColors.success;
  } else if (normalized == 'partial' || normalized == 'partially_paid') {
    color = AppColors.warning;
  } else {
    color = AppColors.danger;
  }

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      status.isEmpty ? 'Pending' : status,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

// ==========================================================================
// PREMIUM BADGE
// ==========================================================================

Widget _premiumBadge({
  required IconData icon,
  required String text,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),

        const SizedBox(width: 6),

        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

// ==========================================================================
// FORMAT AMOUNT
// ==========================================================================

String _formatAmount(dynamic value) {
  final amount = _toDouble(value);

  if (amount == amount.roundToDouble()) {
    return amount.toStringAsFixed(0);
  }

  return amount.toStringAsFixed(2);
}

String _formatPaymentMonth(String value) {
  try {
    final date = DateTime.parse(value);

    return '${date.year} / ${date.month.toString().padLeft(2, '0')}';
  } catch (e) {
    if (value.length >= 7) {
      return '${value.substring(0, 4)} / ${value.substring(5, 7)}';
    }

    return value;
  }
}

String _getCurrentMonthPaymentStatus(dynamic payment) {
  final lastPayment = payment.lastPayment;

  if (lastPayment == null) {
    return 'unpaid';
  }

  final paymentMonth = lastPayment.paymentMonth?.toString() ?? '';

  if (paymentMonth.isEmpty) {
    return 'unpaid';
  }

  try {
    final paidDate = DateTime.parse(
      paymentMonth.length >= 7
          ? '${paymentMonth.substring(0, 7)}-01'
          : '$paymentMonth-01',
    );

    final now = DateTime.now();

    if (paidDate.year == now.year && paidDate.month == now.month) {
      return 'paid';
    }

    return 'unpaid';
  } catch (e) {
    return 'unpaid';
  }
}

double _toDouble(dynamic value) {
  if (value == null) {
    return 0;
  }

  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value.toString()) ?? 0;
}
