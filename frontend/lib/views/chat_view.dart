import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/company.dart';
import '../services/api_service.dart';
import '../widgets/markdown_text.dart';

class ChatView extends StatefulWidget {
  final ApiService apiService;
  final Company? selectedCompany;

  const ChatView({
    super.key,
    required this.apiService,
    this.selectedCompany,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  
  String _selectedAgent = 'ai_manager';
  bool _isLoading = false;
  String _statusText = 'Ready';
  String _llmProvider = 'Loading AI Engine...';
  bool _isLiveAI = false;

  final List<Map<String, String>> _quickActions = [
    {
      'label': '📢 WhatsApp Broadcast',
      'prompt': 'Draft a high-conversion 48-hour VIP flash sale broadcast for our customers with 25% off coupon.',
      'agent': 'marketing',
    },
    {
      'label': '🎨 AI Ad Creative Prompt',
      'prompt': 'Generate a commercial product photography prompt for Midjourney and high-converting ad copy.',
      'agent': 'marketing',
    },
    {
      'label': '📊 Margin & Unit Economics',
      'prompt': 'Analyze our unit economics, calculate CAC:LTV, and forecast quarterly net profit margin targets.',
      'agent': 'finance',
    },
    {
      'label': '✉️ Executive Client Email',
      'prompt': 'Draft a formal follow-up email to an enterprise client confirming milestone delivery and demo scheduling.',
      'agent': 'ai_manager',
    },
    {
      'label': '🛠️ 90-Day MVP Roadmap',
      'prompt': 'Propose a prioritized 90-day product roadmap with MoSCoW feature matrix and technical milestones.',
      'agent': 'product',
    },
    {
      'label': '🎯 Go-To-Market Strategy',
      'prompt': 'Formulate a comprehensive Go-To-Market strategy with SWOT analysis and 30/60/90 day milestones.',
      'agent': 'strategy',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLLMStatus();
    _messages.add(
      ChatMessage(
        sender: 'AI Manager',
        text: '👋 Welcome to your **Autonomous Business AI Partner**.\n\n'
            'Ask any custom question, describe a new business idea, or command automated marketing, strategy, and financials in real time.\n\n'
            'Powered by live Google Gemini & multi-agent intelligence!',
        suggestions: [
          'What are 3 high-profit revenue streams for my company?',
          'Draft high-converting Instagram & Facebook ad copy',
          'Create a 30-day Go-To-Market action plan',
          'Estimate unit economics and gross profit margins',
        ],
      ),
    );
  }

  Future<void> _loadLLMStatus() async {
    try {
      final res = await widget.apiService.getLLMStatus();
      if (mounted) {
        setState(() {
          _llmProvider = res['active_provider']?.toString() ?? 'Simulation Mode';
          _isLiveAI = res['is_live_ai'] == true;
        });
      }
    } catch (_) {}
  }

  void _showAIBrainSettingsDialog() {
    final geminiCtrl = TextEditingController();
    final openaiCtrl = TextEditingController();
    final groqCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            const Icon(Icons.psychology_outlined, color: Color(0xFF6366F1), size: 24),
            const SizedBox(width: 10),
            Text(
              'AI Brain & Model Settings',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isLiveAI ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isLiveAI ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isLiveAI ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        color: _isLiveAI ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _isLiveAI ? 'Live Real-Time AI: $_llmProvider' : 'Offline / Simulation Mode',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _isLiveAI ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Google Gemini API Key (Recommended - Free Tier):',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: geminiCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'AIzaSy... (Get free key at aistudio.google.com)',
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'OpenAI API Key (GPT-4o / GPT-4o-mini):',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF60A5FA)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: openaiCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'sk-proj-...',
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Groq Cloud API Key (Ultra-Fast Free Llama 3.3):',
                  style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: groqCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'gsk_...',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final payload = <String, dynamic>{};
              if (geminiCtrl.text.trim().isNotEmpty) payload['gemini_api_key'] = geminiCtrl.text.trim();
              if (openaiCtrl.text.trim().isNotEmpty) payload['openai_api_key'] = openaiCtrl.text.trim();
              if (groqCtrl.text.trim().isNotEmpty) payload['groq_api_key'] = groqCtrl.text.trim();

              if (payload.isNotEmpty) {
                try {
                  await widget.apiService.updateLLMConfig(payload);
                  await _loadLLMStatus();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ AI Brain keys updated! Active: $_llmProvider'),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update AI keys: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              }
            },
            child: const Text('Save AI Keys'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text, [String? overrideAgent]) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isLoading) return;

    final agent = overrideAgent ?? _selectedAgent;
    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(
        sender: 'User',
        text: prompt,
        agentType: agent,
      ));
      _isLoading = true;
      _statusText = 'Agent is analyzing and executing...';
    });
    _scrollToBottom();

    try {
      final response = await widget.apiService.sendChat(
        prompt: prompt,
        agentType: agent,
        companyId: widget.selectedCompany?.id,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(response);
        _statusText = 'Ready';
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            sender: 'System Alert',
            text: '⚠️ **Connection or Execution Issue**\n\n'
                'Unable to reach backend on port 8001: `$e`\n\n'
                '*Ensure backend is running: `uvicorn backend.app_main:app --port 8001`*',
            agentType: 'system',
          ),
        );
        _statusText = 'Offline / Error';
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAgentMeta = AppConstants.agentRoles.firstWhere(
      (a) => a['id'] == _selectedAgent,
      orElse: () => AppConstants.agentRoles.first,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Top Ribbon with Agent Selector & AI Model Status
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: AppConstants.agentRoles.map((role) {
                      final isSelected = role['id'] == _selectedAgent;
                      final color = role['color'] as Color;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(
                            role['icon'] as IconData,
                            size: 16,
                            color: isSelected ? Colors.white : color,
                          ),
                          label: Text(
                            role['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: color.withValues(alpha: 0.8),
                          backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.5),
                          onSelected: (val) {
                            if (val) {
                              setState(() => _selectedAgent = role['id'] as String);
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _showAIBrainSettingsDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isLiveAI ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isLiveAI ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFF6366F1).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLiveAI ? Icons.auto_awesome_rounded : Icons.psychology_outlined,
                          size: 14,
                          color: _isLiveAI ? const Color(0xFF34D399) : const Color(0xFFA5B4FC),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isLiveAI ? 'Live Gemini AI' : 'AI Model Keys',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: _isLiveAI ? const Color(0xFF34D399) : const Color(0xFFA5B4FC),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Quick Action Feature Chips
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F19),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04)),
              ),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _quickActions.map((action) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(
                      action['label']!,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFE2E8F0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: const Color(0xFF1E1B4B).withValues(alpha: 0.5),
                    side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    onPressed: () => _sendMessage(action['prompt']!, action['agent']),
                  ),
                );
              }).toList(),
            ),
          ),

          // Chat Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            color: const Color(0xFF0F172A),
            child: Row(
              children: [
                if (_isLoading) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 8),
                ] else ...[
                  const Icon(Icons.circle, size: 10, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                ],
                Text(
                  'Active Agent: ${currentAgentMeta['name']} • $_statusText',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (widget.selectedCompany != null)
                  Text(
                    '🏢 ${widget.selectedCompany!.name}',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: const Color(0xFFA5B4FC),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),

          // Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) => _sendMessage(val),
                    maxLines: null,
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Ask ${_selectedAgent.replaceAll('_', ' ')} or execute a business command...',
                      hintStyle: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF64748B)),
                      fillColor: const Color(0xFF0B0F19),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E293B)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                  onPressed: _isLoading ? null : () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    final agentMeta = AppConstants.agentRoles.firstWhere(
      (a) => a['id'] == msg.agentType,
      orElse: () => AppConstants.agentRoles.first,
    );
    final agentColor = agentMeta['color'] as Color;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: agentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: agentColor.withValues(alpha: 0.3)),
              ),
              child: Icon(agentMeta['icon'] as IconData, size: 18, color: agentColor),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF4F46E5)
                    : const Color(0xFF131B2E),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF1E293B),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender Header
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isUser ? 'You' : (agentMeta['name'] as String),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          color: isUser ? Colors.white : const Color(0xFF38BDF8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: msg.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard!'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: Icon(
                          Icons.copy_rounded,
                          size: 14,
                          color: isUser
                              ? Colors.white.withValues(alpha: 0.7)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Message Content with Markdown
                  MarkdownText(
                    text: msg.text,
                    baseStyle: TextStyle(
                      color: isUser ? Colors.white : const Color(0xFFF1F5F9),
                    ),
                  ),

                  // Suggestions chips if available
                  if (msg.suggestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: msg.suggestions.map((s) {
                        return InkWell(
                          onTap: () => _sendMessage(s),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Text(
                              '💡 $s',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFFA5B4FC),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}
