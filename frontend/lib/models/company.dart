class Company {
  final int id;
  final String name;
  final String status;
  final Map<String, dynamic> data;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Company({
    required this.id,
    required this.name,
    required this.status,
    required this.data,
    this.createdAt,
    this.updatedAt,
  });

  String get industry => data['industry']?.toString() ?? 'Technology & Services';
  String get location => data['location']?.toString() ?? 'Global';
  String get budget => data['budget']?.toString() ?? 'Not specified';
  String get goals => data['goals']?.toString() ?? 'Not specified';
  String get businessModel => data['business_model']?.toString() ?? 'B2B SaaS / Services';
  String get targetAudience => data['target_audience']?.toString() ?? 'Enterprise / SMB';
  String? get generatedPlan => data['generated_plan']?.toString();

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? 'Unnamed Enterprise',
      status: json['status']?.toString() ?? 'created',
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'data': data,
    };
  }
}
