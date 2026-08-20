import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../models/company.dart';
import '../models/agent_task.dart';
import '../models/chat_message.dart';
import '../models/social_account.dart';
import '../models/lead.dart';

class ApiService {
  final String baseUrl;
  final http.Client _client;

  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = baseUrl ?? AppConstants.defaultApiUrl,
        _client = client ?? http.Client();

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // Health check
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {'status': 'error', 'statusCode': res.statusCode};
    } catch (e) {
      return {'status': 'offline', 'error': e.toString()};
    }
  }

  // Conversational Chat
  Future<ChatMessage> sendChat({
    required String prompt,
    String agentType = 'ai_manager',
    int? companyId,
  }) async {
    final Map<String, dynamic> payload = {
      'prompt': prompt,
      'agent_type': agentType,
    };
    if (companyId != null) {
      payload['company_id'] = companyId;
    }

    final res = await _client
        .post(Uri.parse('$baseUrl/chat'), headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 45));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final resultText = data['result']?.toString() ?? 'No response generated.';
      final returnedAgent = data['agent_type']?.toString() ?? agentType;
      final suggestionsList = (data['suggestions'] as List<dynamic>?)
              ?.map((s) => s.toString())
              .toList() ??
          [];

      return ChatMessage(
        sender: returnedAgent,
        text: resultText,
        agentType: returnedAgent,
        suggestions: suggestionsList,
      );
    } else {
      throw Exception('Server error (${res.statusCode}): ${res.body}');
    }
  }

  // Companies CRUD
  Future<List<Company>> getCompanies() async {
    final res = await _client
        .get(Uri.parse('$baseUrl/companies'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => Company.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load companies: ${res.body}');
  }

  Future<Company> createCompany({
    required String name,
    String? industry,
    String? budget,
    String? goals,
  }) async {
    final Map<String, dynamic> payload = {'name': name};
    if (industry != null) payload['industry'] = industry;
    if (budget != null) payload['budget'] = budget;
    if (goals != null) payload['goals'] = goals;

    final res = await _client
        .post(Uri.parse('$baseUrl/companies'), headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return Company.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create company: ${res.body}');
  }

  Future<Company> saveCompanyProfile(int companyId, Map<String, dynamic> profile) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/companies/$companyId/profile'),
          headers: _headers,
          body: jsonEncode(profile),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 200) {
      final compRes = await _client.get(Uri.parse('$baseUrl/companies/$companyId'));
      return Company.fromJson(jsonDecode(compRes.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to save profile: ${res.body}');
  }

  Future<String> generateBusinessPlan(int companyId, [Map<String, dynamic>? profile]) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/companies/$companyId/generate-plan'),
          headers: _headers,
          body: jsonEncode(profile ?? {}),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['plan']?.toString() ?? 'Plan generated successfully.';
    }
    throw Exception('Failed to generate business plan: ${res.body}');
  }

  Future<void> deleteCompany(int companyId) async {
    final res = await _client
        .delete(Uri.parse('$baseUrl/companies/$companyId'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Failed to delete company: ${res.body}');
    }
  }

  // Multi-Agent Pipeline
  Future<void> runOrchestration(int companyId, [List<String>? agents]) async {
    final Map<String, dynamic> payload = {};
    if (agents != null) payload['agents'] = agents;

    final res = await _client
        .post(
          Uri.parse('$baseUrl/companies/$companyId/run'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Failed to start orchestration: ${res.body}');
    }
  }

  Future<void> runSingleAgent(int companyId, String agentType) async {
    final res = await _client
        .post(
          Uri.parse('$baseUrl/companies/$companyId/run-agent/$agentType'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode != 200) {
      throw Exception('Failed to execute agent: ${res.body}');
    }
  }

  Future<List<AgentTask>> getCompanyTasks(int companyId) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/companies/$companyId/tasks'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => AgentTask.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch tasks: ${res.body}');
  }

  Future<List<AgentTask>> getAllTasks({int limit = 50}) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/tasks?limit=$limit'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => AgentTask.fromJson(item as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to fetch tasks: ${res.body}');
  }

  // Social & Channels
  Future<List<SocialAccount>> getSocialAccounts(int companyId) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/companies/$companyId/social_accounts'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => SocialAccount.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<SocialAccount> addSocialAccount({
    required int companyId,
    required String platform,
    required String label,
    Map<String, dynamic>? credentials,
  }) async {
    final body = jsonEncode({
      'platform': platform,
      'label': label,
      'credentials': credentials ?? {},
    });

    final res = await _client
        .post(
          Uri.parse('$baseUrl/companies/$companyId/social_accounts'),
          headers: _headers,
          body: body,
        )
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return SocialAccount.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to add social account: ${res.body}');
  }

  Future<Map<String, dynamic>> postToSocial({
    required int companyId,
    required String content,
    List<String>? platforms,
    String? imageUrl,
  }) async {
    final Map<String, dynamic> payload = {'content': content};
    if (platforms != null) payload['platforms'] = platforms;
    if (imageUrl != null) payload['image_url'] = imageUrl;

    final res = await _client
        .post(
          Uri.parse('$baseUrl/companies/$companyId/post'),
          headers: _headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to dispatch social post: ${res.body}');
  }

  // =========================================================================
  // COMPANY KNOWLEDGE BASE & TRAINING DATA
  // =========================================================================

  Future<List<KnowledgeItem>> getCompanyKnowledge(int companyId) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/companies/$companyId/knowledge'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => KnowledgeItem.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<KnowledgeItem> addCompanyKnowledge({
    required int companyId,
    required String title,
    required String category,
    required String content,
  }) async {
    final body = jsonEncode({
      'title': title,
      'category': category,
      'content': content,
    });

    final res = await _client
        .post(Uri.parse('$baseUrl/companies/$companyId/knowledge'), headers: _headers, body: body)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      return KnowledgeItem.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to add knowledge item: ${res.body}');
  }

  Future<void> deleteCompanyKnowledge(int companyId, int knowledgeId) async {
    final res = await _client
        .delete(Uri.parse('$baseUrl/companies/$companyId/knowledge/$knowledgeId'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Failed to delete knowledge item: ${res.body}');
    }
  }

  Future<void> seedKnowledgePreset(int companyId, String preset) async {
    final res = await _client
        .post(Uri.parse('$baseUrl/companies/$companyId/knowledge/seed/$preset'), headers: _headers)
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Failed to seed knowledge preset: ${res.body}');
    }
  }

  // =========================================================================
  // INBOUND LEADS & AUTONOMOUS AUTO-RESPONDER
  // =========================================================================

  Future<List<InboundLead>> getCompanyLeads(int companyId) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/companies/$companyId/leads'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((item) => InboundLead.fromJson(item as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<LeadCaptureResult> captureLead({
    required int companyId,
    required String name,
    String? phone,
    String? email,
    String source = 'ad',
    required String interest,
    bool autoRespond = true,
  }) async {
    final body = jsonEncode({
      'company_id': companyId,
      'name': name,
      'phone': phone,
      'email': email,
      'source': source,
      'interest': interest,
      'auto_respond': autoRespond,
    });

    final res = await _client
        .post(Uri.parse('$baseUrl/leads/capture'), headers: _headers, body: body)
        .timeout(const Duration(seconds: 45));

    if (res.statusCode == 200) {
      return LeadCaptureResult.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to capture lead: ${res.body}');
  }

  // =========================================================================
  // CHANNEL INTEGRATION SETTINGS
  // =========================================================================

  Future<List<Map<String, dynamic>>> getIntegrations(int companyId) async {
    final res = await _client
        .get(Uri.parse('$baseUrl/companies/$companyId/integrations'), headers: _headers)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode == 200) {
      final List<dynamic> list = jsonDecode(res.body);
      return list.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  Future<void> saveIntegration({
    required int companyId,
    required String channel,
    required Map<String, dynamic> config,
  }) async {
    final body = jsonEncode({
      'channel': channel,
      'config': config,
      'is_active': true,
    });

    final res = await _client
        .post(Uri.parse('$baseUrl/companies/$companyId/integrations'), headers: _headers, body: body)
        .timeout(const Duration(seconds: 10));

    if (res.statusCode != 200) {
      throw Exception('Failed to save integration config: ${res.body}');
    }
  }

  // =========================================================================
  // DIRECT OUTBOX DISPATCH (WHATSAPP & EMAIL)
  // =========================================================================

  Future<Map<String, dynamic>> sendDirectWhatsApp({
    required int companyId,
    required String phone,
    required String message,
    int? leadId,
  }) async {
    final Map<String, dynamic> payload = {
      'phone': phone,
      'message': message,
    };
    if (leadId != null) payload['lead_id'] = leadId;

    final res = await _client
        .post(Uri.parse('$baseUrl/companies/$companyId/send-whatsapp'), headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to send WhatsApp message: ${res.body}');
  }

  Future<Map<String, dynamic>> sendDirectEmail({
    required int companyId,
    required String email,
    required String subject,
    required String content,
    int? leadId,
  }) async {
    final Map<String, dynamic> payload = {
      'email': email,
      'subject': subject,
      'content': content,
    };
    if (leadId != null) payload['lead_id'] = leadId;

    final res = await _client
        .post(Uri.parse('$baseUrl/companies/$companyId/send-email'), headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to send email: ${res.body}');
  }

  // =========================================================================
  // LLM BRAIN & MODEL CONFIGURATION
  // =========================================================================

  Future<Map<String, dynamic>> getLLMStatus() async {
    final res = await _client.get(Uri.parse('$baseUrl/config/llm'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    return {'active_provider': 'Offline Mode', 'is_live_ai': false};
  }

  Future<Map<String, dynamic>> updateLLMConfig(Map<String, dynamic> keys) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/config/llm'),
      headers: _headers,
      body: jsonEncode(keys),
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to update LLM configuration');
  }

  Future<Map<String, dynamic>> testLLM(String prompt) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/config/llm/test'),
      headers: _headers,
      body: jsonEncode({'prompt': prompt}),
    ).timeout(const Duration(seconds: 40));
    if (res.statusCode == 200) {
      return jsonDecode(res.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to test LLM connectivity: ${res.body}');
  }
}


