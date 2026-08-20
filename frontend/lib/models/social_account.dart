class SocialAccount {
  final int id;
  final int companyId;
  final String platform;
  final String label;

  SocialAccount({
    required this.id,
    required this.companyId,
    required this.platform,
    required this.label,
  });

  factory SocialAccount.fromJson(Map<String, dynamic> json) {
    return SocialAccount(
      id: json['id'] as int? ?? 0,
      companyId: json['company_id'] as int? ?? 0,
      platform: json['platform'] as String? ?? 'unknown',
      label: json['label'] as String? ?? '',
    );
  }
}
