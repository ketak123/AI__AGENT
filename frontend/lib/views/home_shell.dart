import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/company.dart';
import '../services/api_service.dart';
import 'chat_view.dart';
import 'orchestrator_view.dart';
import 'leads_automation_view.dart';
import 'company_studio_view.dart';
import 'social_hub_view.dart';

class HomeShell extends StatefulWidget {
  final ApiService apiService;

  const HomeShell({super.key, required this.apiService});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;
  List<Company> _companies = [];
  Company? _selectedCompany;
  bool _isServerOnline = false;
  bool _isSidebarExpanded = true;
  String _llmProvider = 'Loading AI Engine...';
  bool _isLiveAI = false;
  Timer? _healthTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _healthTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkServerHealth());
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await _checkServerHealth();
    await _loadCompanies();
    await _loadLLMStatus();
  }

  Future<void> _checkServerHealth() async {
    final health = await widget.apiService.checkHealth();
    if (mounted) {
      setState(() {
        _isServerOnline = health['status'] == 'healthy';
      });
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

  Future<void> _loadCompanies() async {
    try {
      final list = await widget.apiService.getCompanies();
      if (mounted) {
        setState(() {
          _companies = list;
          if (_companies.isEmpty) {
            _selectedCompany = null;
          } else if (_selectedCompany == null) {
            _selectedCompany = _companies.first;
          } else {
            // Update selected company with refreshed data or fallback to first
            _selectedCompany = _companies.firstWhere(
              (c) => c.id == _selectedCompany!.id,
              orElse: () => _companies.first,
            );
          }
        });
      }
    } catch (_) {
      // Handled silently
    }
  }

  Future<void> _confirmDeleteSelectedCompany([Company? targetCompany]) async {
    final companyToDelete = targetCompany ?? _selectedCompany;
    if (companyToDelete == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Enterprise?',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFFCBD5E1), height: 1.4),
            children: [
              const TextSpan(text: 'Are you sure you want to delete '),
              TextSpan(
                text: '"${companyToDelete.name}"',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const TextSpan(text: '?\n\nThis will permanently remove its AI agent tasks, knowledge base records, leads, and social accounts.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('Confirm Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await widget.apiService.deleteCompany(companyToDelete.id);
        await _loadCompanies();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗑️ Enterprise "${companyToDelete.name}" deleted.'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete enterprise: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showCreateCompanyDialog() {
    final nameCtrl = TextEditingController();
    final indCtrl = TextEditingController(text: 'SaaS & Enterprise Automation');
    final budgetCtrl = TextEditingController(text: '\$15,000 / month');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF1E293B)),
        ),
        title: Text(
          'Register New Enterprise',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Enterprise Name', hintText: 'e.g. Apex Global Systems'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: indCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Industry Sector'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: budgetCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Monthly Operating Budget'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              try {
                final newComp = await widget.apiService.createCompany(
                  name: nameCtrl.text.trim(),
                  industry: indCtrl.text.trim(),
                  budget: budgetCtrl.text.trim(),
                );
                await _loadCompanies();
                setState(() => _selectedCompany = newComp);
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('✨ Enterprise "${newComp.name}" registered!'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error creating enterprise: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Create Enterprise'),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog() {
    final geminiCtrl = TextEditingController();
    final openaiCtrl = TextEditingController();
    final groqCtrl = TextEditingController();
    int currentTab = 0;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.settings_suggest_rounded, color: Color(0xFF818CF8), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings & System Console',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'Configure AI brain keys, active enterprise & engine status',
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Settings Tab Bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0F19),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    children: [
                      _settingsTabPill(0, '🤖 AI Brain', currentTab, () => setDialogState(() => currentTab = 0)),
                      _settingsTabPill(1, '🏢 Workspace', currentTab, () => setDialogState(() => currentTab = 1)),
                      _settingsTabPill(2, '🌐 Diagnostics', currentTab, () => setDialogState(() => currentTab = 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Tab Content
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 380),
                  child: SingleChildScrollView(
                    child: currentTab == 0
                        ? _buildAIBrainSettingsTab(geminiCtrl, openaiCtrl, groqCtrl)
                        : currentTab == 1
                            ? _buildWorkspaceSettingsTab()
                            : _buildDiagnosticsSettingsTab(),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            if (currentTab == 0)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);
                  final payload = <String, dynamic>{};
                  if (geminiCtrl.text.trim().isNotEmpty) payload['gemini_api_key'] = geminiCtrl.text.trim();
                  if (openaiCtrl.text.trim().isNotEmpty) payload['openai_api_key'] = openaiCtrl.text.trim();
                  if (groqCtrl.text.trim().isNotEmpty) payload['groq_api_key'] = groqCtrl.text.trim();

                  if (payload.isNotEmpty) {
                    try {
                      await widget.apiService.updateLLMConfig(payload);
                      await _loadLLMStatus();
                      if (mounted) {
                        nav.pop();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('✅ AI Brain keys updated! Active Provider: $_llmProvider'),
                            backgroundColor: const Color(0xFF10B981),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Failed to update AI keys: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  } else {
                    Navigator.pop(ctx);
                  }
                },
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save AI Keys'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _settingsTabPill(int index, String label, int currentTab, VoidCallback onTap) {
    final isSelected = currentTab == index;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.5) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAIBrainSettingsTab(
    TextEditingController geminiCtrl,
    TextEditingController openaiCtrl,
    TextEditingController groqCtrl,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _isLiveAI ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isLiveAI ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFF59E0B).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _isLiveAI ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                color: _isLiveAI ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isLiveAI ? 'Live Real-Time Engine Active' : 'Offline / Simulation Mode',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _isLiveAI ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                      ),
                    ),
                    Text(
                      'Active Provider: $_llmProvider',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                    ),
                  ],
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
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(hintText: 'AIzaSy... (Get free key at aistudio.google.com)'),
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
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(hintText: 'sk-proj-...'),
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
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: const InputDecoration(hintText: 'gsk_...'),
        ),
      ],
    );
  }

  Widget _buildWorkspaceSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Registered Enterprises (${_companies.length})',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              onPressed: () {
                Navigator.pop(context);
                _showCreateCompanyDialog();
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Add New'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_companies.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Text(
              'No enterprises registered yet.',
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _companies.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final comp = _companies[index];
              final isSelected = comp.id == _selectedCompany?.id;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.15) : const Color(0xFF131B2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF1E293B),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.business_rounded, size: 16, color: Color(0xFF818CF8)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                comp.name,
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'ACTIVE',
                                    style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '${comp.industry} • ${comp.budget}',
                            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    if (!isSelected)
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedCompany = comp);
                          Navigator.pop(context);
                        },
                        child: const Text('Switch', style: TextStyle(fontSize: 12, color: Color(0xFF818CF8))),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFF87171)),
                      tooltip: 'Delete "${comp.name}"',
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDeleteSelectedCompany(comp);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildDiagnosticsSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _isServerOnline ? const Color(0xFF34D399) : const Color(0xFFF87171),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isServerOnline ? 'Backend API Server is Online' : 'Backend Server Offline',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: _isServerOnline ? const Color(0xFF34D399) : const Color(0xFFF87171),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Endpoint: ${AppConstants.defaultApiUrl}\nHeartbeat check every 10s • SQLite DB Storage',
                style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Active Autonomous Agents (6 Roles):',
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: AppConstants.agentRoles.map((role) {
            final color = role['color'] as Color;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(role['icon'] as IconData, size: 14, color: color),
                  const SizedBox(width: 6),
                  Text(
                    role['name'] as String,
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 768;

        return Scaffold(
          // Clean borderless UI without bulky upper banner
          appBar: isWideScreen ? null : _buildMinimalMobileHeader(),
          body: Row(
            children: [
              if (isWideScreen) _buildSidebar(),
              Expanded(
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    ChatView(
                      apiService: widget.apiService,
                      selectedCompany: _selectedCompany,
                      onRefreshCompanies: _loadCompanies,
                      onOpenSettings: _showSettingsDialog,
                    ),
                    OrchestratorView(
                      apiService: widget.apiService,
                      selectedCompany: _selectedCompany,
                      onRefreshCompanies: _loadCompanies,
                    ),
                    LeadsAutomationView(
                      apiService: widget.apiService,
                      selectedCompany: _selectedCompany,
                    ),
                    CompanyStudioView(
                      apiService: widget.apiService,
                      companies: _companies,
                      selectedCompany: _selectedCompany,
                      onSelectCompany: (c) => setState(() => _selectedCompany = c),
                      onRefresh: _loadCompanies,
                    ),
                    SocialHubView(
                      apiService: widget.apiService,
                      selectedCompany: _selectedCompany,
                    ),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: isWideScreen ? null : _buildBottomNavBar(),
        );
      },
    );
  }

  PreferredSizeWidget _buildMinimalMobileHeader() {
    return AppBar(
      elevation: 0,
      backgroundColor: const Color(0xFF0F172A),
      titleSpacing: 12,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text(
            _selectedCompany?.name ?? AppConstants.appName,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8), size: 20),
          tooltip: 'Settings & Workspace',
          onPressed: _showSettingsDialog,
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOutCubic,
      width: _isSidebarExpanded ? 240 : 72,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          // Sidebar Brand Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF06B6D4)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                ),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppConstants.appName,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                IconButton(
                  icon: Icon(
                    _isSidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
                    color: const Color(0xFF94A3B8),
                    size: 18,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  tooltip: _isSidebarExpanded ? 'Collapse Navigation' : 'Expand Navigation',
                  onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                ),
              ],
            ),
          ),

          // Workspace / Company Switcher Button in Sidebar
          if (_isSidebarExpanded)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: InkWell(
                onTap: _showSettingsDialog,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.business_rounded, size: 16, color: Color(0xFF818CF8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedCompany?.name ?? 'Select Enterprise',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.unfold_more_rounded, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Tooltip(
                message: _selectedCompany != null ? 'Enterprise: ${_selectedCompany!.name}' : 'Select Enterprise',
                child: InkWell(
                  onTap: _showSettingsDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF131B2E),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: const Icon(Icons.business_rounded, size: 16, color: Color(0xFF818CF8)),
                  ),
                ),
              ),
            ),

          const Divider(height: 20, color: Color(0xFF1E293B)),

          // Navigation Links
          _navItem(0, 'Command Center', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
          _navItem(1, 'Agent Pipeline', Icons.rocket_launch_outlined, Icons.rocket_launch_rounded),
          _navItem(2, 'Leads & Automations', Icons.bolt_outlined, Icons.bolt_rounded),
          _navItem(3, 'Company Studio', Icons.business_outlined, Icons.business_rounded),
          _navItem(4, 'Social & Growth', Icons.campaign_outlined, Icons.campaign_rounded),

          const Spacer(),

          // Settings & More Menu Item in Sidebar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: InkWell(
              onTap: _showSettingsDialog,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: _isSidebarExpanded ? 12 : 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  mainAxisAlignment: _isSidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.settings_outlined, size: 18, color: Color(0xFFA5B4FC)),
                    if (_isSidebarExpanded) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Settings & More',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: _isServerOnline ? const Color(0xFF34D399) : const Color(0xFFF87171),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _navItem(int index, String label, IconData icon, IconData activeIcon) {
    final isSelected = _selectedIndex == index;

    final content = InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _isSidebarExpanded ? 14 : 10,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.4) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: _isSidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
              size: 19,
            ),
            if (_isSidebarExpanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isSidebarExpanded ? 12 : 8,
        vertical: 3,
      ),
      child: _isSidebarExpanded ? content : Tooltip(message: label, child: content),
    );
  }

  Widget _buildBottomNavBar() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
      backgroundColor: const Color(0xFF0F172A),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.chat_bubble_outline_rounded),
          selectedIcon: Icon(Icons.chat_bubble_rounded),
          label: 'Chat',
        ),
        NavigationDestination(
          icon: Icon(Icons.rocket_launch_outlined),
          selectedIcon: Icon(Icons.rocket_launch_rounded),
          label: 'Pipeline',
        ),
        NavigationDestination(
          icon: Icon(Icons.bolt_outlined),
          selectedIcon: Icon(Icons.bolt_rounded),
          label: 'Leads',
        ),
        NavigationDestination(
          icon: Icon(Icons.business_outlined),
          selectedIcon: Icon(Icons.business_rounded),
          label: 'Studio',
        ),
        NavigationDestination(
          icon: Icon(Icons.campaign_outlined),
          selectedIcon: Icon(Icons.campaign_rounded),
          label: 'Social',
        ),
      ],
    );
  }
}
