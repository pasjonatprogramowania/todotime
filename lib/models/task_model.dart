import 'package:flutter/foundation.dart'; // Dla debugPrint

class Task {
  final String id;
  final String name;
  final String? description;
  final int rewardTimeInMinutes; // Nagroda w minutach
  bool isCompleted;
  TaskCategory category; // Dla Matrycy Eisenhowera, zmienione na non-final

  Task({
    required this.id,
    required this.name,
    this.description,
    required this.rewardTimeInMinutes,
    this.isCompleted = false,
    this.category = TaskCategory.importantNotUrgent, // Domyślna kategoria
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'rewardTimeInMinutes': rewardTimeInMinutes,
        'isCompleted': isCompleted,
        'category': category.index, // Zapisz enum jako int (index)
      };

  factory Task.fromJson(Map<String, dynamic> json) {
    try {
      return Task(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        rewardTimeInMinutes: json['rewardTimeInMinutes'] as int,
        isCompleted: json['isCompleted'] as bool? ?? false, // Domyślnie false jeśli null
        // Bezpieczne odczytanie kategorii, z domyślną wartością jeśli indeks jest nieprawidłowy
        category: (json['category'] != null && json['category'] >= 0 && json['category'] < TaskCategory.values.length)
                  ? TaskCategory.values[json['category'] as int]
                  : TaskCategory.importantNotUrgent, // Domyślna kategoria w razie błędu
      );
    } catch (e) {
      debugPrint("Error Task.fromJson: $e. JSON was: $json");
      // Zwróć domyślne zadanie lub rzuć błąd, w zależności od wymagań
      return Task(id: 'error_task', name: 'Error loading task', rewardTimeInMinutes: 0);
    }
  }
}

enum TaskCategory {
  urgentAndImportant,   // Pilne i Ważne (Zrób teraz)
  importantNotUrgent, // Ważne, ale nie Pilne (Zaplanuj)
  urgentNotImportant, // Pilne, ale nie Ważne (Deleguj)
  notUrgentNotImportant // Nie Pilne i nie Ważne (Usuń)
}
