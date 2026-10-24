/// The real content behind the "Today's deep work" card and its siblings
/// in Quick/Explore Mode — previously just hardcoded strings in the
/// mockup. A task is deliberately tiny: a title, an optional note, and
/// whether it's done. Which mode is active decides how much of it gets
/// shown and how, not what the data itself is.
class TaskItem {
  final String id;
  String title;
  String note;
  bool done;
  final DateTime createdAt;

  TaskItem({
    required this.id,
    required this.title,
    this.note = '',
    this.done = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'note': note,
        'done': done,
        'createdAt': createdAt.toIso8601String(),
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String,
        title: json['title'] as String,
        note: json['note'] as String? ?? '',
        done: json['done'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
