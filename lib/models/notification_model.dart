class Notification {
  final String id;
  final String title;
  final String body;
  final String userId;
  final DateTime createdAt;
  bool isRead;

  Notification({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
    required this.createdAt,
    this.isRead = false,
  });

  factory Notification.fromMap(Map<String, dynamic> map) {
    return Notification(
      id: map['id'],
      title: map['title'],
      body: map['body'],
      userId: map['userId'],
      createdAt: DateTime.parse(map['createdAt']),
      isRead: map['isRead'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }
}
