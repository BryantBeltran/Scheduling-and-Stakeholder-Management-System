class AuditLogModel {
  final String id;
  final String actorId;
  final String actorName;
  final String action;
  final String resourceType;
  final String? resourceId;
  final String description;
  final DateTime createdAt;

  const AuditLogModel({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.action,
    required this.resourceType,
    this.resourceId,
    required this.description,
    required this.createdAt,
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as String? ?? '',
      actorId: json['actorId'] as String? ?? '',
      actorName: json['actorName'] as String? ?? 'Unknown',
      action: json['action'] as String? ?? '',
      resourceType: json['resourceType'] as String? ?? '',
      resourceId: json['resourceId'] as String?,
      description: json['description'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  String get actionLabel {
    switch (action) {
      case 'create_event':
        return 'Created Event';
      case 'update_event':
        return 'Updated Event';
      case 'delete_event':
        return 'Deleted Event';
      case 'create_stakeholder':
        return 'Created Stakeholder';
      case 'update_stakeholder':
        return 'Updated Stakeholder';
      case 'delete_stakeholder':
        return 'Deleted Stakeholder';
      case 'assign_stakeholder':
        return 'Assigned Stakeholder';
      case 'update_role':
        return 'Changed Role';
      default:
        return action;
    }
  }
}
