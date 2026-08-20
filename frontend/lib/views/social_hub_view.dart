import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/company.dart';
import '../models/social_account.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_chip.dart';

class SocialHubView extends StatefulWidget {
  final ApiService apiService;
  final Company? selectedCompany;

  const SocialHubView({
    super.key,
    required this.apiService,
    this.selectedCompany,
  });

  @override
  State<SocialHubView> createState() => _SocialHubViewState();
}

class _SocialHubViewState extends State<SocialHubView> {
  final TextEditingController _contentCtrl = TextEditingController();
  final TextEditingController _imageCtrl = TextEditingController();

  List<SocialAccount> _accounts = [];
  bool _isLoadingAccounts = false;
  bool _isDispatching = false;
  List<Map<String, dynamic>> _lastDispatchResults = [];

  final Map<String, bool> _selectedPlatforms = {
    'twitter': true,
    'linkedin': true,
    'instagram': true,
    'whatsapp': true,
    'facebook': false,
  };

  final List<Map<String, String>> _postTemplates = [
    {
      'label': '🚀 Product Launch',
      'content':
          'We are thrilled to announce the official rollout of our Autonomous Business Operations platform! Scale faster with zero friction. Explore today: https://apex.io',
    },
    {
      'label': '🎁 VIP 25% Flash Sale',
      'content':
          '🔥 Weekend VIP Special: Get 25% OFF all enterprise plans using code WEEKEND25. 48 hours only! Claim here: https://apex.io/vip',
    },
    {
      'label': '💡 Thought Leadership',
      'content':
          'Why traditional manual workflows are slowing high-growth teams down — and how autonomous AI agents unlock 10x operational velocity in 2026. A quick breakdown: 🧵👇',
    },
    {
      'label': '🌟 Client Case Study',
      'content':
          'Spotlight: How one enterprise automated 80% of customer inquiries and boosted net margins by 14% in 30 days. Read the full story here: https://apex.io/story',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void didUpdateWidget(covariant SocialHubView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCompany?.id != widget.selectedCompany?.id) {
      _loadAccounts();
    }
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    if (widget.selectedCompany == null) return;
    setState(() => _isLoadingAccounts = true);
    try {
      final accounts = await widget.apiService.getSocialAccounts(
        widget.selectedCompany!.id,
      );
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _isLoadingAccounts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAccounts = false);
    }
  }

  Future<void> _dispatchPost() async {
    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter post content to dispatch')),
      );
      return;
    }

    if (widget.selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or create an enterprise first'),
        ),
      );
      return;
    }

    final activePlatforms = _selectedPlatforms.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (activePlatforms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one channel to dispatch'),
        ),
      );
      return;
    }

    setState(() => _isDispatching = true);

    try {
      final res = await widget.apiService.postToSocial(
        companyId: widget.selectedCompany!.id,
        content: content,
        platforms: activePlatforms,
        imageUrl: _imageCtrl.text.trim().isNotEmpty
            ? _imageCtrl.text.trim()
            : null,
      );

      final resultsList =
          (res['results'] as List<dynamic>?)
              ?.map((item) => item as Map<String, dynamic>)
              .toList() ??
          [];

      if (mounted) {
        setState(() {
          _lastDispatchResults = resultsList;
          _isDispatching = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🎉 Broadcast dispatched to ${resultsList.length} channels!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDispatching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispatch failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddAccountDialog() {
    String platform = 'whatsapp';
    final labelCtrl = TextEditingController();
    final phoneOrIdCtrl = TextEditingController();
    final tokenCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E293B)),
          ),
          title: Text(
            'Connect Business Channel',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: platform,
                    dropdownColor: const Color(0xFF131B2E),
                    decoration: const InputDecoration(labelText: 'Platform'),
                    items: const [
                      DropdownMenuItem(
                        value: 'whatsapp',
                        child: Text('💬 WhatsApp Business (Meta/Twilio)'),
                      ),
                      DropdownMenuItem(
                        value: 'instagram',
                        child: Text('📸 Instagram Business Graph API'),
                      ),
                      DropdownMenuItem(
                        value: 'twitter',
                        child: Text('🐦 Twitter / X'),
                      ),
                      DropdownMenuItem(
                        value: 'linkedin',
                        child: Text('💼 LinkedIn Company Page'),
                      ),
                      DropdownMenuItem(
                        value: 'facebook',
                        child: Text('👥 Facebook Page'),
                      ),
                    ],
                    onChanged: (val) =>
                        setDialogState(() => platform = val ?? 'whatsapp'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: labelCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Account / Sender Label',
                      hintText: platform == 'whatsapp'
                          ? 'e.g. ChaiVeda WhatsApp Official'
                          : 'e.g. Official Brand Feed',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneOrIdCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: platform == 'whatsapp'
                          ? 'Phone Number ID / Twilio Sender'
                          : 'Account ID / User ID (Optional)',
                      hintText: platform == 'whatsapp'
                          ? 'e.g. +91 98765 00000 or 109823...'
                          : 'e.g. 178414...',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tokenCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText:
                          'API Access Token (Optional for live delivery)',
                      hintText:
                          'Leave empty for automated intelligent simulation',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (widget.selectedCompany == null) return;
                Navigator.pop(dialogCtx);
                try {
                  final creds = <String, dynamic>{};
                  if (phoneOrIdCtrl.text.trim().isNotEmpty) {
                    creds['phone_number_id'] = phoneOrIdCtrl.text.trim();
                    creds['ig_user_id'] = phoneOrIdCtrl.text.trim();
                  }
                  if (tokenCtrl.text.trim().isNotEmpty) {
                    creds['access_token'] = tokenCtrl.text.trim();
                  }

                  await widget.apiService.addSocialAccount(
                    companyId: widget.selectedCompany!.id,
                    platform: platform,
                    label: labelCtrl.text.trim().isNotEmpty
                        ? labelCtrl.text.trim()
                        : '${platform.toUpperCase()} Account',
                    credentials: creds,
                  );
                  _loadAccounts();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error adding account: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Connect Channel'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compName = widget.selectedCompany?.name ?? 'All Enterprises';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Omnichannel Social & Growth Hub',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target: $compName • Compose, schedule, and auto-dispatch announcements across X, LinkedIn, Instagram & WhatsApp.',
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAddAccountDialog,
                  icon: const Icon(Icons.add_link, size: 18),
                  label: const Text('Connect Account'),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Two-column layout: Left Composer, Right Accounts & Dispatch Feed
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 850;
                return isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _buildComposerCard()),
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: _buildRightColumn()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildComposerCard(),
                          const SizedBox(height: 20),
                          _buildRightColumn(),
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Multi-Channel Broadcast Composer',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),

          // Quick Templates
          Text(
            'Quick Campaign Presets:',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _postTemplates.map((tpl) {
              return ActionChip(
                label: Text(tpl['label']!),
                backgroundColor: const Color(0xFF1E293B),
                side: const BorderSide(color: Color(0xFF334155)),
                onPressed: () {
                  setState(() => _contentCtrl.text = tpl['content']!);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Content Box
          TextField(
            controller: _contentCtrl,
            maxLines: 5,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: const InputDecoration(
              labelText: 'Campaign Copy / Broadcast Message',
              hintText:
                  'Type your omni-channel post copy or pick a preset above...',
            ),
          ),

          const SizedBox(height: 12),

          // Image URL attachment
          TextField(
            controller: _imageCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Image / Creative URL (Optional)',
              hintText: 'https://images.unsplash.com/...',
              prefixIcon: Icon(Icons.image_outlined, color: Color(0xFF94A3B8)),
            ),
          ),

          const SizedBox(height: 16),

          // Platform Selector
          Text(
            'Select Target Channels:',
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedPlatforms.keys.map((platform) {
              final isChecked = _selectedPlatforms[platform] ?? false;
              return FilterChip(
                label: Text(platform.toUpperCase()),
                selected: isChecked,
                selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.8),
                backgroundColor: const Color(0xFF1E293B),
                onSelected: (val) {
                  setState(() => _selectedPlatforms[platform] = val);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          // Dispatch Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _isDispatching
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                _isDispatching
                    ? 'Dispatching Broadcast...'
                    : 'Dispatch Across Selected Channels',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _isDispatching ? null : _dispatchPost,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightColumn() {
    return Column(
      children: [
        // Connected Channels Card
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Connected Accounts',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                    onPressed: _loadAccounts,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_isLoadingAccounts)
                const Center(child: CircularProgressIndicator())
              else if (_accounts.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'No custom accounts linked yet. The system will use intelligent simulated channel dispatchers.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _accounts.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final acc = _accounts[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            acc.platform == 'twitter'
                                ? Icons.tag
                                : acc.platform == 'linkedin'
                                ? Icons.business
                                : acc.platform == 'instagram'
                                ? Icons.camera_alt_outlined
                                : Icons.chat,
                            size: 18,
                            color: const Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  acc.label.isNotEmpty
                                      ? acc.label
                                      : acc.platform.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  acc.platform.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const StatusChip(status: 'active', compact: true),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Live Dispatch Output
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Live Dispatch Log & Stats',
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              if (_lastDispatchResults.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Ready to broadcast. Click Dispatch to see real-time delivery telemetry.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _lastDispatchResults.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _lastDispatchResults[index];
                    final platform = item['platform']?.toString() ?? 'unknown';
                    final res = item['result'] is Map<String, dynamic>
                        ? item['result'] as Map<String, dynamic>
                        : {};
                    final status = res['status']?.toString() ?? 'success';

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                platform.toUpperCase(),
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const Spacer(),
                              StatusChip(status: status, compact: true),
                            ],
                          ),
                          if (res['stats'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Stats: ${res['stats']}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF34D399),
                              ),
                            ),
                          ],
                          if (res['delivery_rate'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Delivery Rate: ${res['delivery_rate']} (Recipients: ${res['recipients_reached']})',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: const Color(0xFF38BDF8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}
