import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/chat_message.dart';
import '../models/company.dart';
import '../models/lead.dart';
import '../services/api_service.dart';
import '../widgets/markdown_text.dart';
import '../widgets/status_chip.dart';

class ChatView extends StatefulWidget {
  final ApiService apiService;
  final Company? selectedCompany;
  final VoidCallback? onRefreshCompanies;
  final VoidCallback? onOpenSettings;

  const ChatView({
    super.key,
    required this.apiService,
    this.selectedCompany,
    this.onRefreshCompanies,
    this.onOpenSettings,
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

  // Gemini-style sliding Company Data Panel state
  bool _isCompanySliderOpen = false;
  double? _customSliderWidth; // User-adjustable width
  List<KnowledgeItem> _companyKnowledge = [];
  bool _isLoadingKnowledge = false;
  String _knowledgeSearchQuery = '';
  int _sliderTabIndex = 0; // 0: Specs & KPIs, 1: Knowledge Base, 2: Business Plan

  final List<Map<String, dynamic>> _quickActions = [
    {
      'label': 'Growth & Ad Strategy',
      'prompt': 'Draft a high-conversion 48-hour promotional campaign for our target audience with compelling value propositions.',
      'agent': 'marketing',
      'icon': Icons.campaign_outlined,
      'color': Color(0xFFEC4899),
    },
    {
      'label': 'Unit Economics & Margin',
      'prompt': 'Analyze our unit economics, calculate CAC:LTV, and forecast quarterly gross margin targets.',
      'agent': 'finance',
      'icon': Icons.account_balance_outlined,
      'color': Color(0xFF10B981),
    },
    {
      'label': 'Executive Communication',
      'prompt': 'Draft a formal executive communication to a high-value enterprise customer confirming delivery milestones.',
      'agent': 'ai_manager',
      'icon': Icons.mail_outline_rounded,
      'color': Color(0xFF6366F1),
    },
    {
      'label': '90-Day Product Roadmap',
      'prompt': 'Propose a prioritized 90-day technical roadmap with MoSCoW feature matrix and delivery milestones.',
      'agent': 'product',
      'icon': Icons.code_rounded,
      'color': Color(0xFF06B6D4),
    },
    {
      'label': 'Go-To-Market Execution',
      'prompt': 'Formulate a comprehensive Go-To-Market strategy with market positioning and 30/60/90 day milestones.',
      'agent': 'strategy',
      'icon': Icons.insights_outlined,
      'color': Color(0xFF3B82F6),
    },
    {
      'label': 'Omnichannel Social Content',
      'prompt': 'Generate engaging omnichannel thought leadership posts tailored for LinkedIn and Twitter/X.',
      'agent': 'social_media',
      'icon': Icons.share_outlined,
      'color': Color(0xFFF59E0B),
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLLMStatus();
    _loadCompanyKnowledge();
    _startNewChat();
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _messages.add(
        ChatMessage(
          sender: 'AI Manager',
          text: 'Welcome to your **Autonomous Business AI Partner**.\n\n'
              'Ask any custom question, explore growth ideas, or command automated marketing, strategy, and financials in real time.\n\n'
              'Powered by Google Gemini and specialized agent intelligence.',
          suggestions: [
            'What are 3 high-profit revenue streams for my company?',
            'Draft high-converting Instagram & Facebook ad copy',
            'Create a 30-day Go-To-Market action plan',
            'Estimate unit economics and gross profit margins',
          ],
        ),
      );
    });
  }

  @override
  void didUpdateWidget(covariant ChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCompany?.id != widget.selectedCompany?.id) {
      _loadCompanyKnowledge();
    }
  }

  Future<void> _loadCompanyKnowledge() async {
    if (widget.selectedCompany == null) {
      setState(() => _companyKnowledge = []);
      return;
    }
    setState(() => _isLoadingKnowledge = true);
    try {
      final items = await widget.apiService.getCompanyKnowledge(widget.selectedCompany!.id);
      if (mounted) {
        setState(() {
          _companyKnowledge = items;
          _isLoadingKnowledge = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingKnowledge = false);
    }
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
            text: '**Connection or Execution Issue**\n\n'
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        // On screens >= 840px, side-by-side mode; on narrower screens, slide-over overlay
        final isSideBySide = availableWidth >= 840;
        final defaultSliderWidth = isSideBySide
            ? (availableWidth * 0.36).clamp(280.0, 520.0)
            : (availableWidth * 0.88).clamp(240.0, 420.0);
        final sliderWidth = (_customSliderWidth ?? defaultSliderWidth)
            .clamp(220.0, availableWidth * (isSideBySide ? 0.65 : 0.95));

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              // 1. Main Chat Area (Adjusts smoothly according to screen & sidebar width)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                right: (isSideBySide && _isCompanySliderOpen) ? sliderWidth : 0,
                child: _buildChatBody(currentAgentMeta, availableWidth),
              ),

              // 2. Backdrop Overlay on mobile/compact when drawer is open
              if (!isSideBySide && _isCompanySliderOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => setState(() => _isCompanySliderOpen = false),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ),

              // 3. Sliding Company Intelligence Drawer (Adjustable according to screen)
              if (_isCompanySliderOpen) ...[
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: sliderWidth,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      border: Border(
                        left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      boxShadow: [
                        if (!isSideBySide)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(-4, 0),
                          ),
                      ],
                    ),
                    child: _buildCompanyIntelligenceSlider(availableWidth, sliderWidth),
                  ),
                ),

                // 4. Interactive Left Border Drag Resize Handle
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: sliderWidth - 6,
                  width: 12,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeColumn,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          final currentW = _customSliderWidth ?? defaultSliderWidth;
                          final newW = currentW - details.delta.dx;
                          _customSliderWidth = newW.clamp(
                            220.0,
                            availableWidth * (isSideBySide ? 0.65 : 0.95),
                          );
                        });
                      },
                      onDoubleTap: () {
                        setState(() {
                          _customSliderWidth = null; // Reset to auto-responsive
                        });
                      },
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatBody(Map<String, dynamic> currentAgentMeta, double availableWidth) {
    return Column(
      children: [
        // Sleek Minimal Top Header
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              // Gemini-style Agent Role Dropdown Selector
              Flexible(
                child: PopupMenuButton<String>(
                  tooltip: 'Select Active AI Agent',
                  offset: const Offset(0, 42),
                  color: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF1E293B)),
                  ),
                  onSelected: (agentId) {
                    setState(() => _selectedAgent = agentId);
                  },
                  itemBuilder: (context) {
                    return AppConstants.agentRoles.map((role) {
                      final roleId = role['id'] as String;
                      final roleColor = role['color'] as Color;
                      final isCur = roleId == _selectedAgent;
                      return PopupMenuItem<String>(
                        value: roleId,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(role['icon'] as IconData, size: 15, color: roleColor),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    role['name'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: isCur ? FontWeight.bold : FontWeight.w500,
                                      color: isCur ? Colors.white : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  Text(
                                    role['description'] as String,
                                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isCur)
                              const Icon(Icons.check_rounded, size: 16, color: Color(0xFF34D399)),
                          ],
                        ),
                      );
                    }).toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: (currentAgentMeta['color'] as Color).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: (currentAgentMeta['color'] as Color).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          currentAgentMeta['icon'] as IconData,
                          size: 15,
                          color: currentAgentMeta['color'] as Color,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            currentAgentMeta['name'] as String,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),
              const Spacer(),

              // Gemini-style Company Data Slider Toggle Pill
              InkWell(
                onTap: () {
                  setState(() {
                    _isCompanySliderOpen = !_isCompanySliderOpen;
                    if (_isCompanySliderOpen && widget.selectedCompany != null) {
                      _loadCompanyKnowledge();
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: _isCompanySliderOpen
                        ? const Color(0xFF6366F1).withValues(alpha: 0.25)
                        : const Color(0xFF1E293B).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isCompanySliderOpen ? const Color(0xFF818CF8) : const Color(0xFF334155),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isCompanySliderOpen ? Icons.view_sidebar_rounded : Icons.view_sidebar_outlined,
                        size: 14,
                        color: _isCompanySliderOpen ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                      ),
                      if (availableWidth > 460) ...[
                        const SizedBox(width: 6),
                        Text(
                          _isCompanySliderOpen ? 'Company Context: ON' : 'Company Context',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _isCompanySliderOpen ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6),

              // New Chat Action Button (Gemini Style)
              IconButton(
                icon: const Icon(Icons.edit_note_rounded, size: 20, color: Colors.white),
                tooltip: 'Start Fresh Conversation',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                onPressed: _startNewChat,
              ),
            ],
          ),
        ),

        // Chat Messages & Gemini-style Empty State
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length + (_messages.length <= 1 ? 1 : 0),
            itemBuilder: (context, index) {
              if (index < _messages.length) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              }
              // Show Gemini Hero State & Suggested Prompts Grid on fresh chat
              return _buildGeminiHeroEmptyState();
            },
          ),
        ),

        // Status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                const Icon(Icons.circle, size: 8, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  'Active Agent: ${currentAgentMeta['name']} • ${_isLiveAI ? _llmProvider : 'Simulation'} • $_statusText',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.selectedCompany != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isCompanySliderOpen = !_isCompanySliderOpen;
                      if (_isCompanySliderOpen) _loadCompanyKnowledge();
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business_outlined, size: 14, color: Color(0xFFA5B4FC)),
                        const SizedBox(width: 4),
                        Text(
                          widget.selectedCompany!.name,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFFA5B4FC),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isCompanySliderOpen ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                          size: 14,
                          color: const Color(0xFFA5B4FC),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                    fillColor: const Color(0xFF0B0F19),
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    );
  }

  Widget _buildGeminiHeroEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final crossAxisCount = availableWidth > 580 ? 2 : 1;

        return Container(
          margin: const EdgeInsets.only(top: 24, bottom: 20),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            children: [
              // Multicolor Gemini Glowing 4-Pointed Star
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color(0xFF4285F4),
                        Color(0xFF9B72CB),
                        Color(0xFFD96570),
                        Color(0xFFF4B400),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 38,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Gemini Style Large Greeting with Auto Text Fitting
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'What can I help with?',
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select an action starter or ask anything below',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: const Color(0xFF94A3B8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Suggested AI Business Prompts Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 82,
                ),
                itemCount: _quickActions.length,
                itemBuilder: (context, idx) {
                  final action = _quickActions[idx];
                  final actionIcon = action['icon'] as IconData;
                  final actionColor = action['color'] as Color;

                  return InkWell(
                    onTap: () => _sendMessage(action['prompt'] as String, action['agent'] as String),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131B2E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: actionColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(actionIcon, size: 18, color: actionColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    action['label'] as String,
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  action['prompt'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF94A3B8),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompanyIntelligenceSlider([double availableWidth = 800, double sliderWidth = 340]) {
    final comp = widget.selectedCompany;
    if (comp == null) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border(
            left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.business_outlined, size: 48, color: Color(0xFF64748B)),
                const SizedBox(height: 12),
                Text(
                  'No Enterprise Selected',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Register or select an enterprise to inspect live knowledge base docs, specs, and strategic plans without colliding with chats.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isCompanySliderOpen = false),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Close Slider'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filteredKnowledge = _knowledgeSearchQuery.trim().isEmpty
        ? _companyKnowledge
        : _companyKnowledge.where((k) {
            final q = _knowledgeSearchQuery.toLowerCase();
            return k.title.toLowerCase().contains(q) ||
                k.content.toLowerCase().contains(q) ||
                k.category.toLowerCase().contains(q);
          }).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slider Header with Dynamic Width Presets & Drag Handle Tooltip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business_rounded, color: Color(0xFF818CF8), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        comp.name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Drag edge to resize',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                StatusChip(status: comp.status, compact: true),
                const SizedBox(width: 2),
                IconButton(
                  icon: const Icon(Icons.aspect_ratio_rounded, color: Color(0xFF94A3B8), size: 17),
                  tooltip: 'Cycle Width (Compact / Wide / Auto)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () {
                    setState(() {
                      if (_customSliderWidth == null) {
                        _customSliderWidth = (availableWidth * 0.52).clamp(380.0, availableWidth * 0.65);
                      } else if (_customSliderWidth! > 380) {
                        _customSliderWidth = 260.0;
                      } else {
                        _customSliderWidth = null; // Auto reset
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                  tooltip: 'Close Slider (Full Chat View)',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => setState(() => _isCompanySliderOpen = false),
                ),
              ],
            ),
          ),

          // Slider Tab Selector (Gemini Style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: const Color(0xFF0B0F19),
            child: Row(
              children: [
                _sliderTabItem(0, 'Specs', Icons.analytics_outlined),
                const SizedBox(width: 4),
                _sliderTabItem(1, 'Knowledge (${_companyKnowledge.length})', Icons.menu_book_rounded),
                const SizedBox(width: 4),
                _sliderTabItem(2, 'Plan', Icons.description_outlined),
              ],
            ),
          ),

          // Slider Tab Content
          Expanded(
            child: _sliderTabIndex == 0
                ? _buildSliderSpecsTab(comp)
                : _sliderTabIndex == 1
                    ? _buildSliderKnowledgeTab(filteredKnowledge)
                    : _buildSliderPlanTab(comp),
          ),
        ],
      ),
    );
  }

  Widget _sliderTabItem(int index, String label, IconData icon) {
    final isSelected = _sliderTabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _sliderTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderSpecsTab(Company comp) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _specCard('Industry & Niche', comp.industry, Icons.category_outlined, const Color(0xFF60A5FA)),
        const SizedBox(height: 10),
        _specCard('Target Geography', comp.location, Icons.location_on_outlined, const Color(0xFF34D399)),
        const SizedBox(height: 10),
        _specCard('Business Model', comp.businessModel, Icons.layers_outlined, const Color(0xFFA78BFA)),
        const SizedBox(height: 10),
        _specCard('Operating Budget', comp.budget, Icons.payments_outlined, const Color(0xFFFBBF24)),
        const SizedBox(height: 10),
        _specCard('Target Audience / ICP', comp.targetAudience, Icons.group_outlined, const Color(0xFFF472B6)),
        const SizedBox(height: 10),
        _specCard('Strategic Goals', comp.goals, Icons.flag_outlined, const Color(0xFF38BDF8)),
        const SizedBox(height: 18),

        Text(
          'Tailored Company Actions',
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        _tailoredPromptChip(
          'Create ad campaign for ${comp.name}',
          'Draft a high-converting multi-channel marketing campaign specifically designed for ${comp.name} targeting ${comp.targetAudience}.',
          'marketing',
        ),
        const SizedBox(height: 6),
        _tailoredPromptChip(
          'Margin forecast for ${comp.budget}',
          'Analyze our unit economics and calculate expected gross and net margins assuming our operating budget is ${comp.budget}.',
          'finance',
        ),
        const SizedBox(height: 6),
        _tailoredPromptChip(
          '30-Day Growth Strategy',
          'Formulate an actionable 30-day growth strategy for ${comp.name} in the ${comp.industry} sector with concrete KPIs.',
          'strategy',
        ),
      ],
    );
  }

  Widget _specCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131B2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value.isNotEmpty ? value : 'Not configured yet',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: value.isNotEmpty ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tailoredPromptChip(String label, String prompt, String agent) {
    return InkWell(
      onTap: () => _sendMessage(prompt, agent),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B4B).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFA5B4FC), fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF818CF8)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderKnowledgeTab(List<KnowledgeItem> items) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (val) => setState(() => _knowledgeSearchQuery = val),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search knowledge docs...',
              hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 16, color: Color(0xFF94A3B8)),
              fillColor: const Color(0xFF131B2E),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1E293B))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1E293B))),
            ),
          ),
        ),
        Expanded(
          child: _isLoadingKnowledge
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
              : items.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          _companyKnowledge.isEmpty
                              ? 'No documents in knowledge base.\nGo to Company Studio to seed or add documents!'
                              : 'No documents match "$_knowledgeSearchQuery".',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF131B2E),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF1E293B)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFFA5B4FC)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  StatusChip(status: item.category.toUpperCase(), compact: true),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.content,
                                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    final snippet = 'Regarding ${item.title} (${item.category}):\n"${item.content.length > 250 ? '${item.content.substring(0, 250)}...' : item.content}"\n\nQuestion: ';
                                    setState(() {
                                      _controller.text = snippet;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Injected "${item.title}" into prompt!'),
                                        backgroundColor: const Color(0xFF6366F1),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.input_rounded, size: 13, color: Color(0xFF38BDF8)),
                                  label: Text(
                                    'Inject into Prompt',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildSliderPlanTab(Company comp) {
    final plan = comp.generatedPlan;
    if (plan == null || plan.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.description_outlined, size: 36, color: Color(0xFF64748B)),
              const SizedBox(height: 10),
              Text(
                'No Strategy Plan Generated',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Open Company Studio and click "Generate Plan" to synthesize a complete 8-section operating master plan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Row(
          children: [
            Text(
              'Master Strategy Plan',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
              tooltip: 'Copy Business Plan',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: plan));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Plan copied to clipboard!'), duration: Duration(seconds: 1)),
                );
              },
            ),
          ],
        ),
        const Divider(color: Color(0xFF1E293B), height: 16),
        MarkdownText(text: plan),
      ],
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
              constraints: const BoxConstraints(
                maxWidth: 800,
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_outward_rounded, size: 12, color: Color(0xFF818CF8)),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    s,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      color: const Color(0xFFA5B4FC),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
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
