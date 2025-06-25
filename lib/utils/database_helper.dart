import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:myapp/models/task_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tasktime.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY'; // UUID jako string
    const textType = 'TEXT NOT NULL';
    const textNullableType = 'TEXT NULL';
    const boolType = 'INTEGER NOT NULL'; // 0 lub 1
    const intType = 'INTEGER NOT NULL';

    await db.execute('''
CREATE TABLE tasks (
  id $idType,
  name $textType,
  description $textNullableType,
  rewardTimeInMinutes $intType,
  isCompleted $boolType,
  categoryIndex $intType
  )
''');
    // categoryIndex będzie przechowywać TaskCategory.index
    print("Database table 'tasks' created.");
  }

  // --- Metody CRUD ---

  Future<Task> createTask(Task task) async {
    final db = await instance.database;
    // Używamy `toMap` z modelu Task, ale musimy dostosować nazwę pola kategorii
    Map<String, dynamic> row = {
      'id': task.id,
      'name': task.name,
      'description': task.description,
      'rewardTimeInMinutes': task.rewardTimeInMinutes,
      'isCompleted': task.isCompleted ? 1 : 0,
      'categoryIndex': task.category.index,
    };
    await db.insert('tasks', row);
    print("Task created: ${task.name}, ID: ${task.id}");
    return task;
  }

  Future<Task?> getTask(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      'tasks',
      columns: ['id', 'name', 'description', 'rewardTimeInMinutes', 'isCompleted', 'categoryIndex'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _taskFromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Task>> getAllTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks', orderBy: 'name ASC'); // Można sortować np. po dacie dodania
    print("Fetched ${result.length} tasks from DB.");
    return result.map((json) => _taskFromMap(json)).toList();
  }

  Future<int> updateTask(Task task) async {
    final db = await instance.database;
    Map<String, dynamic> row = {
      'name': task.name,
      'description': task.description,
      'rewardTimeInMinutes': task.rewardTimeInMinutes,
      'isCompleted': task.isCompleted ? 1 : 0,
      'categoryIndex': task.category.index,
    };
    print("Updating task: ${task.name}, ID: ${task.id}, Completed: ${task.isCompleted}");
    return db.update(
      'tasks',
      row,
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(String id) async {
    final db = await instance.database;
    print("Deleting task with ID: $id");
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Helper do konwersji mapy z bazy na obiekt Task
  Task _taskFromMap(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      rewardTimeInMinutes: json['rewardTimeInMinutes'] as int,
      isCompleted: (json['isCompleted'] as int) == 1,
      category: TaskCategory.values[json['categoryIndex'] as int],
    );
  }


  Future close() async {
    final db = await instance.database;
    db.close();
    _database = null; // Ważne, aby przy następnym wywołaniu `database` DB była reinicjalizowana
    print("Database closed.");
  }
}
