import 'package:flutter/material.dart';
import '../theme_service.dart';
import '../user_database.dart';
import '../services/custom_exercise_service.dart';

class YourExerciseScreen extends StatefulWidget {
  final String usernameOrEmail;
  final Future<int> Function({
    required String usernameOrEmail,
    required String name,
    String? category,
    String? intensity,
    int? durationMin,
    int? reps,
    int? sets,
    String? notes,
    int? estCalories,
  })?
  onSaveCustomExercise; // for tests
  final bool closeOnSubmit;
  const YourExerciseScreen({
    super.key,
    required this.usernameOrEmail,
    this.onSaveCustomExercise,
    this.closeOnSubmit = true,
  });

  @override
  State<YourExerciseScreen> createState() => _YourExerciseScreenState();
}

class _YourExerciseScreenState extends State<YourExerciseScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _repsController = TextEditingController();
  final TextEditingController _setsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _category = 'Cardio';
  String _intensity = 'Medium';
  bool _submitting = false;
  String? _userGender;

  Color get _primaryColor => ThemeService.getPrimaryColor(_userGender);
  Color get _backgroundColor => ThemeService.getBackgroundColor(_userGender);

  @override
  void initState() {
    super.initState();
    _loadUserGender();
  }

  Future<void> _loadUserGender() async {
    try {
      final gender = await UserDatabase().getUserSex(widget.usernameOrEmail);
      if (mounted) {
        setState(() {
          _userGender = gender;
        });
      }
    } catch (e) {
      debugPrint('Error loading user gender: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _repsController.dispose();
    _setsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final name = _nameController.text.trim();
    final duration = int.tryParse(_durationController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());
    final sets = int.tryParse(_setsController.text.trim());

    final effectiveCalories = _estimateCalories(duration, _intensity);

    // Save locally; allow test injection override
    final saver =
        widget.onSaveCustomExercise ?? UserDatabase().saveCustomExercise;
    final id = await saver(
      usernameOrEmail: widget.usernameOrEmail,
      name: name,
      category: _category,
      intensity: _intensity,
      durationMin: duration,
      reps: reps,
      sets: sets,
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      estCalories: effectiveCalories,
    );

    if (!mounted) return;
    setState(() => _submitting = false);
    final detail = [
      if (duration != null) 'for ${duration}m',
      if (reps != null && sets != null) '$sets x $reps',
    ].join(' ');

    // Fire-and-forget backend submission
    // ignore: unawaited_futures
    CustomExerciseService.submitCustomExercise(
      user: widget.usernameOrEmail,
      name: name,
      category: _category,
      intensity: _intensity,
      durationMin: duration,
      reps: reps,
      sets: sets,
      notes:
          _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
      estCalories: effectiveCalories,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Saved "$name" ($_category) $detail – $effectiveCalories kcal est. (#$id)',
        ),
      ),
    );
    if (widget.closeOnSubmit) {
      Navigator.pop(context, true);
    }
  }

  int _estimateCalories(int? durationMin, String intensity) {
    if (durationMin == null || durationMin <= 0) return 0;
    // Simple heuristic for preview only
    final perMin = switch (intensity) {
      'Low' => 3,
      'Medium' => 6,
      'High' => 9,
      _ => 5,
    };
    return perMin * durationMin;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Your Exercise'),
        backgroundColor: _backgroundColor,
        foregroundColor: _primaryColor,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Exercise name *',
                      labelStyle: TextStyle(color: _primaryColor),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _primaryColor, width: 2),
                      ),
                    ),
                    validator:
                        (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Please enter exercise name'
                                : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _category,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            labelStyle: TextStyle(color: _primaryColor),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Cardio',
                              child: Text('Cardio'),
                            ),
                            DropdownMenuItem(
                              value: 'Strength',
                              child: Text('Strength'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged:
                              (v) => setState(() => _category = v ?? 'Cardio'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _intensity,
                          decoration: InputDecoration(
                            labelText: 'Intensity',
                            labelStyle: TextStyle(color: _primaryColor),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Low', child: Text('Low')),
                            DropdownMenuItem(
                              value: 'Medium',
                              child: Text('Medium'),
                            ),
                            DropdownMenuItem(
                              value: 'High',
                              child: Text('High'),
                            ),
                          ],
                          onChanged:
                              (v) => setState(() => _intensity = v ?? 'Medium'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Duration (min)',
                            labelStyle: TextStyle(color: _primaryColor),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if ((v == null || v.isEmpty) &&
                                (_repsController.text.isEmpty ||
                                    _setsController.text.isEmpty)) {
                              return 'Provide duration or reps & sets';
                            }
                            final n = int.tryParse(v ?? '');
                            if (v != null &&
                                v.isNotEmpty &&
                                (n == null || n <= 0 || n > 480)) {
                              return 'Enter 1-480';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _repsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Reps',
                            labelStyle: TextStyle(color: _primaryColor),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _setsController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Sets',
                            labelStyle: TextStyle(color: _primaryColor),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: _primaryColor,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes (equipment, description, etc.)',
                      labelStyle: TextStyle(color: _primaryColor),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _primaryColor, width: 2),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon:
                          _submitting
                              ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Icon(Icons.send),
                      label: Text(_submitting ? 'Submitting...' : 'Submit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 4,
                        shadowColor: _primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
