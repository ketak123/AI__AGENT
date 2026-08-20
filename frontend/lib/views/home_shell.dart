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
          if (_selectedCompany == null && _companies.isNotEmpty) {
            _selectedCompany = _companies.first;
          } else if (_selectedCompany != null) {
            // Update selected company with refreshed data
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 768;

        return Scaffold(
          appBar: _buildTopAppBar(),
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

  PreferredSizeWidget _buildTopAppBar() {
    return AppBar(
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
        // Company Selector Dropdown
        if (_companies.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _selectedCompany?.id,
                dropdownColor: const Color(0xFF0F172A),
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
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
          ),

        // Server Status Badge
        Container(
          margin: const EdgeInsets.only(right: 16),
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
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _navItem(0, 'Command Center', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
          _navItem(1, 'Agent Pipeline', Icons.rocket_launch_outlined, Icons.rocket_launch_rounded),
          _navItem(2, 'Leads & Automations', Icons.bolt_outlined, Icons.bolt_rounded),
          _navItem(3, 'Company Studio', Icons.business_outlined, Icons.business_rounded),
          _navItem(4, 'Social & Growth', Icons.campaign_outlined, Icons.campaign_rounded),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
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
          ),
        ],
      ),
    );
  }

  Widget _navItem(int index, String label, IconData icon, IconData activeIcon) {
    final isSelected = _selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.18) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF6366F1).withValues(alpha: 0.4) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? const Color(0xFF818CF8) : const Color(0xFF94A3B8),
                size: 20,
              ),
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
          ),
        ),
      ),
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
