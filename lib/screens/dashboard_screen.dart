import 'package:flutter/material.dart';
import 'package:myapp/models/task_model.dart';
import 'package:myapp/screens/add_edit_task_screen.dart';
import 'package:myapp/screens/settings_screen.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'dart:async';
import 'package:myapp/utils/database_helper.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Task> _tasks = [];
  bool _isLoadingTasks = true;
  bool _isListView = true;
  Duration _availableTime = const Duration(seconds: 0);
  StreamSubscription<Map<String, dynamic>?>? _serviceEventSubscription;
  late DatabaseHelper _dbHelper;

  @override
  void initState() {
    super.initState();
    _dbHelper = DatabaseHelper.instance;
    _loadTasksFromDb();

    // Łączymy nasłuchiwanie na różne eventy w jedną subskrypcję, jeśli to możliwe,
    // lub zarządzamy nimi osobno. FlutterBackgroundService().on() zwraca nową subskrypcję za każdym razem.
    // Dla prostoty, zachowam oddzielne, ale w większej aplikacji można by to zrefaktoryzować.
    _serviceEventSubscription = FlutterBackgroundService().on('update').listen((event) {
      if (event != null && event.containsKey('available_time_seconds')) {
        if (mounted) {
          setState(() {
            _availableTime = Duration(seconds: event['available_time_seconds']);
          });
        }
      }
    });

    // Nasłuchiwanie na event resetu/zmiany zadań
    // Jeśli FlutterBackgroundService().on() zawsze zwraca nową subskrypcję,
    // musimy ją też zapisać i anulować.
    // Alternatywnie, można by użyć jednego strumienia i filtrować eventy po stronie Dart.
    // Na razie, dla uproszczenia, dodam drugą subskrypcję.
    // W bardziej rozbudowanym scenariuszu, lepiej byłoby mieć jeden strumień eventów z serwisu.
    FlutterBackgroundService().on('tasksPossiblyChanged').listen((event) {
      if (mounted) {
        print("UI: Received 'tasksPossiblyChanged' event from service. Reloading tasks.");
        _loadTasksFromDb();
      }
    });
  }

  @override
  void dispose() {
    _serviceEventSubscription?.cancel();
    // Jeśli dodaliśmy drugą subskrypcję, ją też trzeba by anulować.
    super.dispose();
  }

  Future<void> _loadTasksFromDb() async {
    if (!mounted) return;
    setState(() { _isLoadingTasks = true; });
    try {
      final tasks = await _dbHelper.getAllTasks();
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoadingTasks = false;
        });
      }
    } catch (e) {
      print("Error loading tasks from DB: $e");
      if (mounted) {
        setState(() { _isLoadingTasks = false; });
      }
    }
  }

  void _navigateToAddTaskScreen({Task? taskToEdit}) async {
    final result = await Navigator.of(context).push<Task>(
      MaterialPageRoute(
        builder: (context) => AddEditTaskScreen(taskToEdit: taskToEdit),
      ),
    );

    if (result != null) {
      if (taskToEdit != null) {
        await _dbHelper.updateTask(result);
      } else {
        await _dbHelper.createTask(result);
      }
      _loadTasksFromDb();
    }
  }

  void _navigateToSettingsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    ).then((_) {
      _loadTasksFromDb(); // Przeładuj zadania i ustawienia po powrocie
      // Usługa w tle sama przeładuje ustawienia po ich zmianie w SettingsScreen,
      // ale UI zadań może potrzebować odświeżenia.
    });
  }

  Future<void> _deleteTask(String id, BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: const Text('Czy na pewno chcesz usunąć to zadanie?'),
        actions: <Widget>[
          TextButton(child: const Text('Anuluj'), onPressed: () => Navigator.of(dialogContext).pop(false)),
          TextButton(child: const Text('Usuń'), onPressed: () => Navigator.of(dialogContext).pop(true)),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteTask(id);
      _loadTasksFromDb();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zadanie usunięte'), duration: Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoadingTasks) {
      return Scaffold(appBar: AppBar(title: const Text('TaskTime')), body: const Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskTime'),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(icon: Icon(Icons.settings_outlined, color: theme.colorScheme.primary), tooltip: 'Ustawienia', onPressed: _navigateToSettingsScreen),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dostępny czas na dziś', style: theme.textTheme.headlineSmall?.copyWith(color: theme.textTheme.titleMedium?.color)),
            const SizedBox(height: 8),
            Text(
              '${_availableTime.inHours.toString().padLeft(2, '0')}:${(_availableTime.inMinutes % 60).toString().padLeft(2, '0')}:${(_availableTime.inSeconds % 60).toString().padLeft(2, '0')}',
              style: theme.textTheme.headlineLarge?.copyWith(fontSize: 48, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton(onPressed: () => setState(() => _isListView = true), child: Text("Lista")),
              SizedBox(width: 10),
              ElevatedButton(onPressed: () => setState(() => _isListView = false), child: Text("Matryca")),
            ]),
            const SizedBox(height: 16),
            Expanded(child: _isListView ? _buildTasksListView() : _buildEisenhowerMatrixView()),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _navigateToAddTaskScreen(), tooltip: 'Dodaj zadanie', child: const Icon(Icons.add)),
    );
  }

  Widget _buildTasksListView() {
    if (_tasks.isEmpty) return const Center(child: Text('Brak zadań. Dodaj nowe!'));
    return ListView.builder(
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return Dismissible(
          key: Key(task.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) => _deleteTask(task.id, context),
          background: Container(color: Colors.redAccent.withOpacity(0.7), padding: const EdgeInsets.symmetric(horizontal: 20), alignment: AlignmentDirectional.centerEnd, child: const Icon(Icons.delete_sweep_outlined, color: Colors.white)),
          child: TaskCard(
            task: task,
            onChanged: (bool? newValue) async {
              setState(() { task.isCompleted = newValue ?? false; });
              await _dbHelper.updateTask(task);
              if (task.isCompleted) {
                FlutterBackgroundService().invoke("addRewardTime", {"minutes": task.rewardTimeInMinutes});
              } else {
                FlutterBackgroundService().invoke("subtractRewardTime", {"minutes": task.rewardTimeInMinutes});
              }
            },
            onTap: () => _navigateToAddTaskScreen(taskToEdit: task),
          ),
        );
      },
    );
  }

  Widget _buildEisenhowerMatrixView() { /* ... bez zmian ... */
    final theme = Theme.of(context);
    List<Task> urgentAndImportant = _tasks.where((t) => t.category == TaskCategory.urgentAndImportant && !t.isCompleted).toList();
    List<Task> importantNotUrgent = _tasks.where((t) => t.category == TaskCategory.importantNotUrgent && !t.isCompleted).toList();
    List<Task> urgentNotImportant = _tasks.where((t) => t.category == TaskCategory.urgentNotImportant && !t.isCompleted).toList();
    List<Task> notUrgentNotImportant = _tasks.where((t) => t.category == TaskCategory.notUrgentNotImportant && !t.isCompleted).toList();

    return Column(
      children: [
        Expanded(child: Row(children: [
            _buildMatrixQuadrant("Pilne i Ważne", urgentAndImportant, Colors.redAccent.withOpacity(0.7), theme),
            _buildMatrixQuadrant("Ważne, nie Pilne", importantNotUrgent, Colors.orangeAccent.withOpacity(0.7), theme),
        ])),
        Expanded(child: Row(children: [
            _buildMatrixQuadrant("Pilne, nie Ważne", urgentNotImportant, Colors.blueAccent.withOpacity(0.7), theme),
            _buildMatrixQuadrant("Nie Pilne i nie Ważne", notUrgentNotImportant, Colors.grey.withOpacity(0.7), theme),
        ])),
      ],
    );
  }

  Widget _buildMatrixQuadrant(String title, List<Task> tasks, Color headerColor, ThemeData theme) { /* ... bez zmian ... */
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(border: Border.all(color: headerColor.withOpacity(0.5)), borderRadius: BorderRadius.circular(8.0), color: theme.cardColor.withOpacity(0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(color: headerColor, borderRadius: const BorderRadius.only(topLeft: Radius.circular(7.0), topRight: Radius.circular(7.0))),
              child: Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? Center(child: Text("Brak zadań", style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(4.0),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) => _buildMiniTaskCard(tasks[index], theme),
                    ),
            ),
        ]),
      ),
    );
  }

  Widget _buildMiniTaskCard(Task task, ThemeData theme) { /* ... bez zmian ... */
    return InkWell(
      onTap: () => _navigateToAddTaskScreen(taskToEdit: task),
      child: Card(
        elevation: 1, color: theme.cardColor, margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
        child: Padding(padding: const EdgeInsets.all(6.0), child: Row(children: [
            SizedBox(height: 20.0, width: 20.0, child: Checkbox(
                value: task.isCompleted, visualDensity: VisualDensity.compact,
                onChanged: (bool? newValue) async {
                    setState(() { task.isCompleted = newValue ?? false; });
                    await _dbHelper.updateTask(task);
                    if (task.isCompleted) FlutterBackgroundService().invoke("addRewardTime", {"minutes": task.rewardTimeInMinutes});
                    else FlutterBackgroundService().invoke("subtractRewardTime", {"minutes": task.rewardTimeInMinutes});
                },
            )),
            const SizedBox(width: 6),
            Expanded(child: Text(task.name, style: theme.textTheme.bodySmall?.copyWith(decoration: task.isCompleted ? TextDecoration.lineThrough : null, color: task.isCompleted ? theme.hintColor : theme.textTheme.bodySmall?.color), overflow: TextOverflow.ellipsis)),
        ])),
      ),
    );
  }
}

class TaskCard extends StatelessWidget { /* ... bez zmian ... */
  final Task task;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onTap;

  const TaskCard({super.key, required this.task, required this.onChanged, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardColor, margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(onTap: onTap, child: Padding(
          padding: const EdgeInsets.fromLTRB(4.0, 8.0, 12.0, 8.0),
          child: Row(children: [
              Checkbox(value: task.isCompleted, onChanged: onChanged, activeColor: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(task.name, style: task.isCompleted ? TextStyle(decoration: TextDecoration.lineThrough, color: theme.textTheme.titleMedium?.color) : theme.textTheme.bodyLarge)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text('+${task.rewardTimeInMinutes} min', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
              ),
          ]))));
  }
}
```
Zastosuję ten kod.
