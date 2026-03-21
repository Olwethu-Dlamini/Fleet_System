// ============================================
// FILE: lib/models/app_notification.dart
// PURPOSE: In-app notification data model
// ============================================

class AppNotification {
  final int id;
  final int? jobId;
  final String type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    this.jobId,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      jobId: json['job_id'] as int?,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      isRead: json['is_read'] == true || json['is_read'] == 1,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      jobId: jobId,
      type: type,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
