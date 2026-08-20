import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/company.dart';
import '../models/lead.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/markdown_text.dart';
import '../widgets/status_chip.dart';
import '../widgets/metric_tile.dart';

class CompanyStudioView extends StatefulWidget {
  final ApiService apiService;
  final List<Company> companies;
  final Company? selectedCompany;
  final Function(Company) onSelectCompany;
  final VoidCallback onRefresh;

  const CompanyStudioView({
    super.key,
    required this.apiService,
    required this.companies,
    this.selectedCompany,
    required this.onSelectCompany,
    required this.onRefresh,
  });

  @override
  State<CompanyStudioView> createState() => _CompanyStudioViewState();
}

class _CompanyStudioViewState extends State<CompanyStudioView> {
  bool _isGeneratingPlan = false;
  bool _isSaving = false;
  bool _isLoadingKnowledge = false;
  List<KnowledgeItem> _knowledgeItems = [];

  // Controllers for editing company profile
  final _nameCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _audienceCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _goalsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _populateFields();
    _loadKnowledge();
  }

  @override
  void didUpdateWidget(covariant CompanyStudioView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCompany?.id != widget.selectedCompany?.id) {
      _populateFields();
      _loadKnowledge();
    }
  }

  Future<void> _loadKnowledge() async {
    if (widget.selectedCompany == null) return;
    setState(() => _isLoadingKnowledge = true);
    try {
      final items = await widget.apiService.getCompanyKnowledge(widget.selectedCompany!.id);
      if (mounted) {
        setState(() {
          _knowledgeItems = items;
          _isLoadingKnowledge = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingKnowledge = false);
    }
  }

  Future<void> _seedPreset(String preset) async {
    if (widget.selectedCompany == null) return;
    try {
      await widget.apiService.seedKnowledgePreset(widget.selectedCompany!.id, preset);
      await _loadKnowledge();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text(
            '🌱 Seeded $preset training data into company knowledge base!',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error seeding: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteKnowledge(int id) async {
    if (widget.selectedCompany == null) return;
    try {
      await widget.apiService.deleteCompanyKnowledge(widget.selectedCompany!.id, id);
      _loadKnowledge();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddKnowledgeDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String category = 'product';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
          title: Text(
            'Add Training Document / Data',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Topic / Document Title',
                      hintText: 'e.g. Royal Assam CTC Blend Specs & Pricing',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    dropdownColor: const Color(0xFF0F172A),
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(value: 'product', child: Text('Product Specs & Pricing')),
                      DropdownMenuItem(value: 'brand_tone', child: Text('Brand Voice & Guidelines')),
                      DropdownMenuItem(value: 'faq', child: Text('Customer FAQs & Policies')),
                      DropdownMenuItem(value: 'past_campaign', child: Text('High-Performing Past Ads/Emails')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => category = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentCtrl,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Training Content / Historical Examples',
                      hintText: 'Paste detailed product info, past ad templates, pricing lists, or brand voice notes...',
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
                if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                await widget.apiService.addCompanyKnowledge(
                  companyId: widget.selectedCompany!.id,
                  title: titleCtrl.text.trim(),
                  category: category,
                  content: contentCtrl.text.trim(),
                );
                _loadKnowledge();
              },
              child: const Text('Save Document'),
            ),
          ],
        ),
      ),
    );
  }

  void _populateFields() {
    final c = widget.selectedCompany;
    if (c != null) {
      _nameCtrl.text = c.name;
      _industryCtrl.text = c.industry;
      _locationCtrl.text = c.location;
      _modelCtrl.text = c.businessModel;
      _audienceCtrl.text = c.targetAudience;
      _budgetCtrl.text = c.budget;
      _goalsCtrl.text = c.goals;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _industryCtrl.dispose();
    _locationCtrl.dispose();
    _modelCtrl.dispose();
    _audienceCtrl.dispose();
    _budgetCtrl.dispose();
    _goalsCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (widget.selectedCompany == null) return;
    setState(() => _isSaving = true);

    try {
      final profile = {
        'company_name': _nameCtrl.text.trim(),
        'industry': _industryCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'business_model': _modelCtrl.text.trim(),
        'target_audience': _audienceCtrl.text.trim(),
        'budget': _budgetCtrl.text.trim(),
        'goals': _goalsCtrl.text.trim(),
      };

      await widget.apiService.saveCompanyProfile(widget.selectedCompany!.id, profile);
      widget.onRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company profile saved successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _generatePlan() async {
    if (widget.selectedCompany == null) return;
    setState(() => _isGeneratingPlan = true);

    try {
      final profile = {
        'company_name': _nameCtrl.text.trim(),
        'industry': _industryCtrl.text.trim(),
        'location': _locationCtrl.text.trim(),
        'business_model': _modelCtrl.text.trim(),
        'target_audience': _audienceCtrl.text.trim(),
        'budget': _budgetCtrl.text.trim(),
        'goals': _goalsCtrl.text.trim(),
      };

      await widget.apiService.generateBusinessPlan(widget.selectedCompany!.id, profile);
      widget.onRefresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Master Business Plan Generated!'),
          backgroundColor: Color(0xFF6366F1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate plan: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingPlan = false);
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
              Navigator.pop(ctx);
              try {
                final newComp = await widget.apiService.createCompany(
                  name: nameCtrl.text.trim(),
                  industry: indCtrl.text.trim(),
                  budget: budgetCtrl.text.trim(),
                );
                widget.onRefresh();
                widget.onSelectCompany(newComp);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating company: $e'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final c = widget.selectedCompany;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar: Enterprise Selector & Creator
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company Strategy & Profile Studio',
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Configure core business parameters, target audience, and generate executive AI strategy documents.',
                        style: GoogleFonts.inter(fontSize: 13.5, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateCompanyDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Enterprise'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Enterprise Selector Cards Carousel
            SizedBox(
              height: 85,
              child: widget.companies.isEmpty
                  ? Center(
                      child: Text(
                        'No enterprises registered yet. Create one with the button above!',
                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.companies.length,
                      itemBuilder: (context, index) {
                        final comp = widget.companies[index];
                        final isSelected = comp.id == c?.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: InkWell(
                            onTap: () => widget.onSelectCompany(comp),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 220,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                                    : const Color(0xFF131B2E),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF6366F1)
                                      : const Color(0xFF1E293B),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          comp.name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      StatusChip(status: comp.status, compact: true),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comp.industry,
                                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 24),

            if (c != null) ...[
              // KPI Overview Grid
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 800;
                  return Row(
                    children: [
                      Expanded(
                        child: MetricTile(
                          label: 'Enterprise Status',
                          value: c.status.replaceAll('_', ' ').toUpperCase(),
                          icon: Icons.shield_outlined,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MetricTile(
                          label: 'Operating Budget',
                          value: c.budget,
                          icon: Icons.payments_outlined,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      if (isWide) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: MetricTile(
                            label: 'Business Model',
                            value: c.businessModel,
                            icon: Icons.layers_outlined,
                            color: const Color(0xFF06B6D4),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // Profile Form & Business Plan Generator
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 900;
                  return isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildProfileForm(c)),
                            const SizedBox(width: 20),
                            Expanded(flex: 6, child: _buildPlanViewer(c)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildProfileForm(c),
                            const SizedBox(height: 20),
                            _buildPlanViewer(c),
                          ],
                        );
                },
              ),

              const SizedBox(height: 24),

              // Knowledge Base & Training Documents Section
              _buildKnowledgeBaseSection(c),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKnowledgeBaseSection(Company c) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Color(0xFF818CF8), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📚 Company Knowledge Base & AI Training Hub',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Store product catalogs, pricing, brand voice guidelines, and historical data for hyper-personalized agents.',
                      style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddKnowledgeDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preset Seed Chips
          Row(
            children: [
              Text(
                'Quick Data Presets: ',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 8),
              ActionChip(
                backgroundColor: const Color(0xFF131B2E),
                side: const BorderSide(color: Color(0xFF10B981)),
                avatar: const Text('🍵', style: TextStyle(fontSize: 12)),
                label: Text(
                  'Seed Indian Tea Company Data',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF34D399), fontWeight: FontWeight.w600),
                ),
                onPressed: () => _seedPreset('indian_tea'),
              ),
              const SizedBox(width: 8),
              ActionChip(
                backgroundColor: const Color(0xFF131B2E),
                side: const BorderSide(color: Color(0xFF06B6D4)),
                avatar: const Text('💻', style: TextStyle(fontSize: 12)),
                label: Text(
                  'Seed SaaS Platform Data',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                ),
                onPressed: () => _seedPreset('saas'),
              ),
            ],
          ),
          const Divider(height: 28, color: Color(0xFF1E293B)),

          if (_isLoadingKnowledge)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: Color(0xFF6366F1))))
          else if (_knowledgeItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.auto_stories_outlined, size: 40, color: Color(0xFF64748B)),
                  const SizedBox(height: 10),
                  Text(
                    'No Training Documents Added Yet',
                    style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Click "Seed Indian Tea Company Data" or "Add Document" to train the AI on specific products & FAQs.',
                    style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _knowledgeItems.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, idx) {
                final k = _knowledgeItems[idx];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0F19),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                k.title,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFA5B4FC)),
                              ),
                              const SizedBox(width: 8),
                              StatusChip(status: k.category.toUpperCase(), compact: true),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFF87171)),
                            onPressed: () => _deleteKnowledge(k.id),
                            tooltip: 'Delete Document',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      MarkdownText(text: k.content),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProfileForm(Company c) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Enterprise Profile Settings',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                onPressed: _isSaving ? null : _saveProfile,
                icon: _isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 16),
                label: Text(_isSaving ? 'Saving...' : 'Save Profile'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Company / Brand Name'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _industryCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Industry / Niche'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _locationCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Target Geography / HQ'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Business Model (e.g. B2B SaaS, Agency, Marketplace)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _audienceCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Target Audience / ICP'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _budgetCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Monthly Operating & Ad Budget'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _goalsCtrl,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Key Strategic Objectives & KPIs'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanViewer(Company c) {
    final plan = c.generatedPlan;

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Master AI Business Plan',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const Spacer(),
              if (plan != null)
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: Color(0xFF94A3B8)),
                  tooltip: 'Copy Plan',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: plan));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied Business Plan to clipboard!'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: _isGeneratingPlan ? null : _generatePlan,
                icon: _isGeneratingPlan
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome, size: 16),
                label: Text(_isGeneratingPlan ? 'Generating...' : (plan == null ? 'Generate Plan' : 'Regenerate Plan')),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1E293B), height: 24),
          if (plan != null)
            Container(
              constraints: const BoxConstraints(maxHeight: 520),
              child: SingleChildScrollView(
                child: MarkdownText(text: plan),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.description_outlined, size: 48, color: Color(0xFF64748B)),
                    const SizedBox(height: 12),
                    Text(
                      'No Business Plan Generated Yet',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Click "Generate Plan" above to have the Chief Strategy Agent synthesize a full 8-section operating plan.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
