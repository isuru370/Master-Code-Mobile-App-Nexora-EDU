import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../student_grade/presentation/bloc/student_grade/student_grade_bloc.dart';
import '../../data/datasources/temporary_card_remote_data_source.dart';
import '../../data/models/admission_dialog_result.dart';
import '../../data/models/students_model.dart';
import '../bloc/students/students_bloc.dart';
import '../widgets/admission_dialog.dart';
import '../widgets/admission_receipt_dialog.dart';
import '../widgets/branch_selector_field.dart';

class CreateStudentPage extends StatefulWidget {
  const CreateStudentPage({super.key});

  @override
  State<CreateStudentPage> createState() => _CreateStudentPageState();
}

class _CreateStudentPageState extends State<CreateStudentPage> {
  final _formKey = GlobalKey<FormState>();

  final _temporaryQrCodeController = TextEditingController();
  final _quickImageIdController = TextEditingController();
  final _lnameController = TextEditingController();
  final _guardianMobileController = TextEditingController();

  int? _selectedGradeId;
  int? _selectedBranchId;
  String _selectedGender = 'male';
  bool _isLoading = false;
  int? _selectedAdmissionId;

  /// The card the server will give automatically (TMP045 ...)
  NextTemporaryCard? _nextCard;
  bool _loadingNextCard = false;

  @override
  void initState() {
    super.initState();
    context.read<StudentGradeBloc>().add(GetStudentGradesEvent());
    _loadNextCard();
  }

  Future<void> _loadNextCard() async {
    setState(() => _loadingNextCard = true);

    final next = await TemporaryCardRemoteDataSource().next();

    if (!mounted) return;

    setState(() {
      _nextCard = next;
      _loadingNextCard = false;
    });
  }

  @override
  void dispose() {
    _temporaryQrCodeController.dispose();
    _quickImageIdController.dispose();
    _lnameController.dispose();
    _guardianMobileController.dispose();
    super.dispose();
  }

  Future<void> _openImageCapture() async {
    final result = await Navigator.pushNamed(
      context,
      '/image_capture',
      arguments: {'registered': true},
    );

    if (!mounted) return;

    if (result is String && result.trim().isNotEmpty) {
      setState(() {
        _quickImageIdController.text = result.trim();
      });
    }
  }

  Future<void> _showAdmissionDialog() async {
    // Check the form first - no point choosing an admission for a bad form
    if (!_formKey.currentState!.validate()) return;

    if (_selectedBranchId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a branch')));
      return;
    }

    final result = await showDialog<AdmissionDialogResult>(
      context: context,
      builder: (_) => const AdmissionDialog(),
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedAdmissionId = result.admissionId;
    });

    _submitStudent();
  }

  void _submitStudent() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedGradeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select grade')));
      return;
    }

    if (_selectedBranchId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a branch')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final quickImageText = _quickImageIdController.text.trim();

    final student = StudentModel(
      branchId: _selectedBranchId,
      // Empty = the server gives the next issued card automatically
      temporaryQrCode: _temporaryQrCodeController.text.trim().isEmpty
          ? null
          : 'TMP${_temporaryQrCodeController.text.trim()}',
      quickImageId: (quickImageText.isEmpty) ? null : quickImageText,
      initialName: _lnameController.text.trim(),
      gender: _selectedGender,
      guardianMobile: _guardianMobileController.text.trim(),
      gradeId: _selectedGradeId!,
      admission: _selectedAdmissionId,
    );

    context.read<StudentsBloc>().add(CreateStudentEvent(student: student));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<StudentsBloc, StudentsState>(
      listener: (context, state) {
        if (state is StudentsLoading) {
          setState(() {
            _isLoading = true;
          });
        } else if (state is StudentsCreated) {
          setState(() {
            _isLoading = false;
          });

          final response = state.response;
          final payment = response.admissionPayment;

          // Receipt first (prints automatically), then the Custom ID and
          // the card to give, then a fresh form
          final receipt = payment != null
              ? showAdmissionReceiptDialog(context: context, response: response)
              : Future<void>.value();

          receipt.then((_) async {
            if (!mounted) return;

            await _showRegisteredDialog(
              customId: response.student.customId ?? '-',
              card: response.student.temporaryQrCode ?? '-',
              name: response.student.initialName,
            );

            if (!mounted) return;

            _clearForm();
            _loadNextCard();
          });
        } else if (state is StudentsError) {
          setState(() {
            _isLoading = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.danger,
              content: Text(state.message),
            ),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text(
              'Temporary Card Registration',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          body: Stack(
            children: [
              Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppColors.largeShadow,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Student Registration',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Register and manage student records easily',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: .82),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 18),

                          // Student's main branch
                          BranchSelectorField(
                            enabled: !_isLoading,
                            onChanged: (id) => _selectedBranchId = id,
                          ),

                          const SizedBox(height: 18),

                          _buildNextCardBox(),

                          const SizedBox(height: 12),

                          _buildTextField(
                            controller: _temporaryQrCodeController,
                            label: 'Different card (optional)',
                            icon: Icons.qr_code_scanner_rounded,
                            prefixText: 'TMP',
                            keyboardType: TextInputType.number,
                            requiredField: false,
                            customValidator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) return null;
                              if (!RegExp(r'^\d+$').hasMatch(text)) {
                                return 'Numbers only, e.g. 045';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Leave empty: the next card is given automatically. '
                            'Type a number only if you give a different card.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),

                          const SizedBox(height: 18),

                          _buildTextField(
                            controller: _quickImageIdController,
                            label: 'QuickImage Id',
                            icon: Icons.image_rounded,
                            requiredField: false,
                            customValidator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return null;
                              }

                              final regex = RegExp(r'^QP-\d{3}$');
                              if (!regex.hasMatch(value.trim())) {
                                return 'Use format like QP-001';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isLoading ? null : _openImageCapture,
                              icon: const Icon(Icons.add_a_photo_rounded),
                              label: const Text('Add Image'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          _buildTextField(
                            controller: _lnameController,
                            label: 'Initial Name',
                            icon: Icons.badge_rounded,
                          ),

                          const SizedBox(height: 18),

                          DropdownButtonFormField<String>(
                            initialValue: _selectedGender,
                            decoration: _inputDecoration(
                              label: 'Gender',
                              icon: Icons.wc_rounded,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'male',
                                child: Text('Male'),
                              ),
                              DropdownMenuItem(
                                value: 'female',
                                child: Text('Female'),
                              ),
                              DropdownMenuItem(
                                value: 'other',
                                child: Text('Other'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedGender = value;
                              });
                            },
                          ),

                          const SizedBox(height: 18),

                          _buildTextField(
                            controller: _guardianMobileController,
                            label: 'Guardian Mobile',
                            icon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                          ),

                          const SizedBox(height: 18),

                          BlocBuilder<StudentGradeBloc, StudentGradeState>(
                            builder: (context, state) {
                              if (state is StudentGradeLoading) {
                                return const Padding(
                                  padding: EdgeInsets.all(18),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }

                              if (state is StudentGradeLoaded) {
                                return DropdownButtonFormField<int>(
                                  initialValue: _selectedGradeId,
                                  decoration: _inputDecoration(
                                    label: 'Select Grade',
                                    icon: Icons.class_rounded,
                                  ),
                                  items: state.grades.map((g) {
                                    return DropdownMenuItem(
                                      value: g.gradeId,
                                      child: Text('Grade ${g.gradeName}'),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedGradeId = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Please select grade';
                                    }
                                    return null;
                                  },
                                );
                              }

                              if (state is StudentGradeError) {
                                return Text(
                                  state.message,
                                  style: const TextStyle(
                                    color: AppColors.danger,
                                  ),
                                );
                              }

                              return const SizedBox();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: 18,
                left: 18,
                right: 18,
                child: SafeArea(
                  child: SizedBox(
                    height: 60,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _showAdmissionDialog,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isLoading ? 'Creating Student...' : 'Create Student',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              if (_isLoading)
                Container(
                  color: Colors.black.withValues(alpha: .25),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    TextInputType? keyboardType,
    String? prefixText,
    bool requiredField = true,
    String? Function(String?)? customValidator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.words,
      onChanged: (value) {
        if (label == 'Initial Name') {
          final capitalized = value
              .split(' ')
              .map((word) {
                if (word.isEmpty) return '';
                return word[0].toUpperCase() + word.substring(1).toLowerCase();
              })
              .join(' ');

          if (value != capitalized) {
            controller.value = TextEditingValue(
              text: capitalized,
              selection: TextSelection.collapsed(offset: capitalized.length),
            );
          }
        }
      },
      decoration: _inputDecoration(
        label: label,
        icon: icon,
        prefixText: prefixText,
      ),
      validator:
          customValidator ??
          (value) {
            if (!requiredField) {
              return null;
            }

            if (value == null || value.trim().isEmpty) {
              return 'Required field';
            }

            return null;
          },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? icon,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      filled: true,
      fillColor: AppColors.background,
      prefixIcon: icon != null ? Icon(icon) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    );
  }

  Widget _buildNextCardBox() {
    final next = _nextCard?.next;
    final noneLeft = _nextCard != null && next == null;

    final Color color = noneLeft ? AppColors.danger : AppColors.success;

    String title;
    String subtitle;

    if (_loadingNextCard) {
      title = 'Checking the next card...';
      subtitle = '';
    } else if (_nextCard == null) {
      title = 'Next card: automatic';
      subtitle = 'The next issued card is given when you register.';
    } else if (noneLeft) {
      title = 'No issued cards left';
      subtitle = _nextCard!.message ?? 'Issue more temporary cards on the web first.';
    } else {
      title = 'Next card: $next';
      subtitle = '${_nextCard!.issuedLeft} issued card(s) left';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Icon(
            noneLeft ? Icons.warning_amber_rounded : Icons.badge_rounded,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadingNextCard ? null : _loadNextCard,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  /// After registering: Custom ID + the card to give, in big letters
  Future<void> _showRegisteredDialog({
    required String customId,
    required String card,
    required String name,
  }) {
    Widget big(String label, String value, Color color) {
      return Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      );
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 10),
            Expanded(child: Text('Student Registered')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (name.isNotEmpty) ...[
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 14),
            ],
            big('Custom ID', customId, AppColors.dark),
            const SizedBox(height: 16),
            big('Give this card', card, AppColors.primary),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    _temporaryQrCodeController.clear();
    _lnameController.clear();
    _guardianMobileController.clear();
    _quickImageIdController.clear();

    setState(() {
      _selectedGradeId = null;
      _selectedAdmissionId = null;
      _selectedGender = 'male';
    });
  }
}
