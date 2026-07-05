enum EmergencyStatus {
  active,
  resolved,
  cancelled,
}

class Emergency {
  final String? id;
  final String userId;
  final double latitude;
  final double longitude;
  final EmergencyStatus status;
  final String? incidentType;
  final String? description;
  final DateTime timestamp;
  final DateTime? resolvedAt;
  final int contactsNotified;
  final bool policeNotified;

  Emergency({
    this.id,
    required this.userId,
    required this.latitude,
    required this.longitude,
    this.status = EmergencyStatus.active,
    this.incidentType,
    this.description,
    required this.timestamp,
    this.resolvedAt,
    this.contactsNotified = 0,
    this.policeNotified = false,
  });

  factory Emergency.fromJson(Map<String, dynamic> json) {
    return Emergency(
      id: json['id'],
      userId: json['user_id'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      status: EmergencyStatus.values.firstWhere(
        (e) => e.toString() == json['status'],
        orElse: () => EmergencyStatus.active,
      ),
      incidentType: json['incident_type'],
      description: json['description'],
      timestamp:
          DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      contactsNotified: json['contacts_notified'] ?? 0,
      policeNotified: json['police_notified'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'latitude': latitude,
      'longitude': longitude,
      'status': status.toString(),
      'incident_type': incidentType,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'contacts_notified': contactsNotified,
      'police_notified': policeNotified,
    };
  }
}
