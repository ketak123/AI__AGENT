class KnowledgeItem {
  final int id;
  final int companyId;
  final String title;
  final String category;
  final String content;
  final DateTime? createdAt;

  KnowledgeItem({
    required this.id,
    required this.companyId,
    required this.title,
    required this.category,
    required this.content,
    this.createdAt,
  });

  factory KnowledgeItem.fromJson(Map<String, dynamic> json) {
    return KnowledgeItem(
      id: json['id'] as int? ?? 0,
      companyId: json['company_id'] as int? ?? 0,
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'company_id': companyId,
        'title': title,
        'category': category,
        'content': content,
      };
}

class LeadInteraction {
  final int id;
  final int leadId;
  final int companyId;
  final String channel;
  final String direction;
  final String message;
  final String status;
  final String? providerResponse;
  final DateTime? createdAt;

  LeadInteraction({
    required this.id,
    required this.leadId,
    required this.companyId,
    required this.channel,
    required this.direction,
    required this.message,
    required this.status,
    this.providerResponse,
    this.createdAt,
  });

  factory LeadInteraction.fromJson(Map<String, dynamic> json) {
    return LeadInteraction(
      id: json['id'] as int? ?? 0,
      leadId: json['lead_id'] as int? ?? 0,
      companyId: json['company_id'] as int? ?? 0,
      channel: json['channel']?.toString() ?? 'whatsapp',
      direction: json['direction']?.toString() ?? 'outbound',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'sent',
      providerResponse: json['provider_response']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
    );
  }
}

class InboundLead {
  final int id;
  final int companyId;
  final String name;
  final String? phone;
  final String? email;
  final String source;
  final String interest;
  final String status;
  final String? customData;
  final DateTime? createdAt;
  final List<LeadInteraction> interactions;

  InboundLead({
    required this.id,
    required this.companyId,
    required this.name,
    this.phone,
    this.email,
    required this.source,
    required this.interest,
    required this.status,
    this.customData,
    this.createdAt,
    this.interactions = const [],
  });

  factory InboundLead.fromJson(Map<String, dynamic> json) {
    final rawInteractions = json['interactions'] as List<dynamic>? ?? [];
    return InboundLead(
      id: json['id'] as int? ?? 0,
      companyId: json['company_id'] as int? ?? 0,
      name: json['name']?.toString() ?? 'Unknown Lead',
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      source: json['source']?.toString() ?? 'ad',
      interest: json['interest']?.toString() ?? '',
      status: json['status']?.toString() ?? 'new',
      customData: json['custom_data']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      interactions: rawInteractions
          .map((i) => LeadInteraction.fromJson(i as Map<String, dynamic>))
          .toList(),
    );
  }
}

class LeadCaptureResult {
  final String status;
  final int leadId;
  final int companyId;
  final String? whatsappResponse;
  final String? emailResponse;
  final String? waLink;
  final String? mailtoLink;
  final List<String> channelsNotified;
  final String message;

  LeadCaptureResult({
    required this.status,
    required this.leadId,
    required this.companyId,
    this.whatsappResponse,
    this.emailResponse,
    this.waLink,
    this.mailtoLink,
    required this.channelsNotified,
    required this.message,
  });

  factory LeadCaptureResult.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['channels_notified'] as List<dynamic>? ?? [];
    return LeadCaptureResult(
      status: json['status']?.toString() ?? 'processed',
      leadId: json['lead_id'] as int? ?? 0,
      companyId: json['company_id'] as int? ?? 0,
      whatsappResponse: json['whatsapp_response']?.toString(),
      emailResponse: json['email_response']?.toString(),
      waLink: json['wa_link']?.toString(),
      mailtoLink: json['mailto_link']?.toString(),
      channelsNotified: rawChannels.map((e) => e.toString()).toList(),
      message: json['message']?.toString() ?? '',
    );
  }
}
