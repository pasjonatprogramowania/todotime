import 'package:flutter/material.dart';
import 'package:myapp/models/task_model.dart';
import 'package:myapp/utils/database_helper.dart'; // Import DatabaseHelper
import 'package:uuid/uuid.dart'; // Do generowania ID

class AddEditTaskScreen extends StatefulWidget {
  final Task? taskToEdit;

  const AddEditTaskScreen({super.key, this.taskToEdit});

  @override
  State<AddEditTaskScreen> createState() => _AddEditTaskScreenState();
}

class _AddEditTaskScreenState extends State<AddEditTaskScreen> {
  final _formKey = GlobalKey<FormState>();

  late String _taskName = '';
  String? _taskDescription;
  TaskCategory _selectedCategory = TaskCategory.importantNotUrgent;
  double _rewardTimeInMinutes = 30;

  bool get _isEditing => widget.taskToEdit != null;
  late DatabaseHelper _dbHelper;
  var uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper.instance;
    if (_isEditing && widget.taskToEdit != null) {
      _taskName = widget.taskToEdit!.name;
      _taskDescription = widget.taskToEdit!.description;
      _selectedCategory = widget.taskToEdit!.category;
      _rewardTimeInMinutes = widget.taskToEdit!.rewardTimeInMinutes.toDouble();
    } else {
      _taskName = '';
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final taskToSave = Task(
        id: _isEditing ? widget.taskToEdit!.id : uuid.v4(),
        name: _taskName,
        description: _taskDescription,
        rewardTimeInMinutes: _rewardTimeInMinutes.toInt(),
        category: _selectedCategory,
        isCompleted: _isEditing ? widget.taskToEdit!.isCompleted : false,
      );

      if (_isEditing) {
        await _dbHelper.updateTask(taskToSave);
        print("UI: Task updated in DB via AddEditScreen: ${taskToSave.name}");
      } else {
        await _dbHelper.createTask(taskToSave);
        print("UI: Task created in DB via AddEditScreen: ${taskToSave.name}");
      }

      if (mounted) {
           Navigator.of(context).pop(taskToSave);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edytuj zadanie' : 'Dodaj nowe zadanie'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                initialValue: _taskName, // Usunięto warunek _isEditing, initialValue może być null
                decoration: const InputDecoration(
                  labelText: 'Nazwa zadania',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nazwa zadania jest wymagana';
                  }
                  return null;
                },
                onSaved: (value) => _taskName = value!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _taskDescription,
                decoration: const InputDecoration(
                  labelText: 'Opis (opcjonalnie)',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
                onSaved: (value) => _taskDescription = value?.trim(),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<TaskCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategoria (Matryca Eisenhowera)',
                  border: OutlineInputBorder(),
                ),
                items: TaskCategory.values.map((TaskCategory category) {
                  return DropdownMenuItem<TaskCategory>(
                    value: category,
                    child: Text(_getCategoryName(category)),
                  );
                }).toList(),
                onChanged: (TaskCategory? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
              ),
              const SizedBox(height: 24),
              Text('Nagroda czasowa: ${_rewardTimeInMinutes.toInt()} minut', style: theme.textTheme.titleMedium),
              Slider(
                value: _rewardTimeInMinutes,
                min: 5,
                max: 180,
                divisions: (180 - 5) ~/ 5,
                label: '${_rewardTimeInMinutes.toInt()} min',
                activeColor: theme.colorScheme.primary,
                inactiveColor: theme.colorScheme.primary.withOpacity(0.3),
                onChanged: (double value) {
                  setState(() {
                    _rewardTimeInMinutes = value;
                  });
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  textStyle: TextStyle(fontSize: 18, color: theme.colorScheme.onPrimary),
                ),
                child: Text(_isEditing ? 'Zapisz zmiany' : 'Dodaj zadanie', style: TextStyle(color: theme.colorScheme.onPrimary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCategoryName(TaskCategory category) {
    switch (category) {
      case TaskCategory.urgentAndImportant:
        return 'Pilne i Ważne';
      case TaskCategory.importantNotUrgent:
        return 'Ważne, nie Pilne';
      case TaskCategory.urgentNotImportant:
        return 'Pilne, nie Ważne';
      case TaskCategory.notUrgentNotImportant:
        return 'Nie Pilne i nie Ważne';
      default:
        return '';
    }
  }
}
