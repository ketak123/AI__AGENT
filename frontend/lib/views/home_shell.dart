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
  }

  Future<void> _checkServerHealth() async {
    final health = await widget.apiService.checkHealth();
    if (mounted) {
      setState(() {
        _isServerOnline = health['status'] == 'healthy';
      });
    }
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

  Future<void> _confirmDeleteSelectedCompany() async {
    if (_selectedCompany == null) return;
    final companyToDelete = _selectedCompany!;

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 768;

        return Scaffold(
          appBar: _buildTopAppBar(isWideScreen),
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

  PreferredSizeWidget _buildTopAppBar(bool isWideScreen) {
    return AppBar(
      titleSpacing: 8,
      leading: isWideScreen
          ? IconButton(
              icon: Icon(
                _isSidebarExpanded ? Icons.menu_open_rounded : Icons.menu_rounded,
                color: const Color(0xFFA5B4FC),
              ),
              tooltip: _isSidebarExpanded ? 'Collapse Sidebar (Gemini Mode)' : 'Expand Sidebar',
              onPressed: () {
                setState(() => _isSidebarExpanded = !_isSidebarExpanded);
              },
            )
          : null,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppConstants.appName,
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Autonomous Multi-Agent Enterprise Engine',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Company Selector with Delete Option
        if (_companies.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedCompany?.id,
                    dropdownColor: const Color(0xFF0F172A),
                    icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8), size: 18),
                    items: _companies.map((c) {
                      return DropdownMenuItem<int>(
                        value: c.id,
                        child: Text(
                          '🏢 ${c.name}',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedCompany = _companies.firstWhere((c) => c.id == val);
                        });
                      }
                    },
                  ),
                ),
                if (_selectedCompany != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFF87171)),
                    tooltip: 'Delete "${_selectedCompany!.name}"',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: _confirmDeleteSelectedCompany,
                  ),
                ],
              ],
            ),
          ),
        ],

        // Server Status Badge
        Container(
          margin: const EdgeInsets.only(left: 4, right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _isServerOnline
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : const Color(0xFFEF4444).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isServerOnline
                  ? const Color(0xFF10B981).withValues(alpha: 0.4)
                  : const Color(0xFFEF4444).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.circle,
                size: 8,
                color: _isServerOnline ? const Color(0xFF34D399) : const Color(0xFFF87171),
              ),
              const SizedBox(width: 6),
              Text(
                _isServerOnline ? 'API Online' : 'API Offline',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _isServerOnline ? const Color(0xFF34D399) : const Color(0xFFF87171),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: _isSidebarExpanded ? 240 : 70,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _navItem(0, 'Command Center', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
          _navItem(1, 'Agent Pipeline', Icons.rocket_launch_outlined, Icons.rocket_launch_rounded),
          _navItem(2, 'Leads & Automations', Icons.bolt_outlined, Icons.bolt_rounded),
          _navItem(3, 'Company Studio', Icons.business_outlined, Icons.business_rounded),
          _navItem(4, 'Social & Growth', Icons.campaign_outlined, Icons.campaign_rounded),
          const Spacer(),
          if (_isSidebarExpanded)
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF131B2E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Multi-Agent System',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '6 Autonomous Agents Active',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF34D399)),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Tooltip(
                message: '6 Multi-Agents Active',
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: const Icon(Icons.hub_rounded, size: 16, color: Color(0xFF34D399)),
                ),
              ),
            ),
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
          vertical: 12,
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
              size: 20,
            ),
            if (_isSidebarExpanded) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
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
        vertical: 4,
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
