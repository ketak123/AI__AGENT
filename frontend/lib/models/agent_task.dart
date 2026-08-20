class AgentTask {
  final int id;
  final int companyId;
  final String agentType;
  final String title;
  final String status;
  final String? result;
  final String? error;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AgentTask({
    required this.id,
    required this.companyId,
    required this.agentType,
    required this.title,
    required this.status,
    this.result,
    this.error,
    this.createdAt,
    this.updatedAt,
  });

  bool get isRunning => status == 'running' || status == 'pending';
  bool get isDone => status == 'done' || status == 'completed';
  bool get isFailed => status == 'failed';

  factory AgentTask.fromJson(Map<String, dynamic> json) {
    return AgentTask(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      companyId: int.tryParse(json['company_id']?.toString() ?? '') ?? 0,
      agentType: json['agent_type']?.toString() ?? 'general',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      result: json['result']?.toString(),
      error: json['error']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}
