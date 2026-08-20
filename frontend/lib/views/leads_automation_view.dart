import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/company.dart';
import '../models/lead.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_chip.dart';
import '../widgets/markdown_text.dart';

class LeadsAutomationView extends StatefulWidget {
  final ApiService apiService;
  final Company? selectedCompany;

  const LeadsAutomationView({
    super.key,
    required this.apiService,
    this.selectedCompany,
  });

  @override
  State<LeadsAutomationView> createState() => _LeadsAutomationViewState();
}

class _LeadsAutomationViewState extends State<LeadsAutomationView> {
  final _nameCtrl = TextEditingController(text: 'Rahul Sharma');
  final _phoneCtrl = TextEditingController(text: '+91 98765 43210');
  final _emailCtrl = TextEditingController(text: 'rahul.sharma@example.com');
  final _interestCtrl = TextEditingController(
    text: 'Looking for authentic Assam CTC and Masala Chai wholesale sample packs for my cafe chain.',
  );

  String _selectedSource = 'instagram_ad';
  bool _isProcessing = false;
  bool _isLoadingLeads = false;
  LeadCaptureResult? _lastResult;
  List<InboundLead> _leads = [];

  final List<Map<String, String>> _samplePresets = [
    {
      'label': '☕ Indian Tea Wholesale (Assam CTC)',
      'name': 'Vikram Mehra',
      'phone': '+91 98220 12345',
      'email': 'vikram@tajhotelsgroup.demo',
      'source': 'facebook_ad',
      'interest': 'Inquiring about 50kg monthly bulk supply of Royal Assam CTC Gold & Darjeeling First Flush.',
    },
    {
      'label': '🌿 Masala Chai Retail Box Sample',
      'name': 'Priya Deshmukh',
      'phone': '+91 99100 88765',
      'email': 'priya.deshmukh@gmail.demo',
      'source': 'instagram_ad',
      'interest': 'Saw your Instagram Ad for Ayurvedic Masala Chai! How can I order the 4-blend sampler kit?',
    },
    {
      'label': '💻 Enterprise SaaS Trial Signup',
      'name': 'Michael Chen',
      'phone': '+1 (415) 555-0192',
      'email': 'm.chen@datadrive.demo',
      'source': 'google_ad',
      'interest': 'Need an AI workflow automation sandbox demo for our 20-person support engineering team.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadLeads();
  }

  @override
  void didUpdateWidget(covariant LeadsAutomationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCompany?.id != widget.selectedCompany?.id) {
      _loadLeads();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeads() async {
    if (widget.selectedCompany == null) return;
    setState(() => _isLoadingLeads = true);
    try {
      final list = await widget.apiService.getCompanyLeads(widget.selectedCompany!.id);
      if (mounted) {
        setState(() {
          _leads = list;
          _isLoadingLeads = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLeads = false);
    }
  }

  Future<void> _submitLead() async {
    if (widget.selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create an enterprise first')),
      );
      return;
    }

    final name = _nameCtrl.text.trim();
    final interest = _interestCtrl.text.trim();
    if (name.isEmpty || interest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter lead name and inquiry details')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final result = await widget.apiService.captureLead(
        companyId: widget.selectedCompany!.id,
        name: name,
        phone: _phoneCtrl.text.trim().isNotEmpty ? _phoneCtrl.text.trim() : null,
        email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        source: _selectedSource,
        interest: interest,
        autoRespond: true,
      );

      if (mounted) {
        setState(() {
          _lastResult = result;
          _isProcessing = false;
        });
        _loadLeads();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              '🎉 Lead Captured! Auto-responded via ${result.channelsNotified.join(', ')}',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  void _applyPreset(Map<String, String> p) {
    setState(() {
      _nameCtrl.text = p['name'] ?? '';
      _phoneCtrl.text = p['phone'] ?? '';
      _emailCtrl.text = p['email'] ?? '';
      _selectedSource = p['source'] ?? 'instagram_ad';
      _interestCtrl.text = p['interest'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectedCompany == null) {
      return Center(
        child: Text(
          'Please select an enterprise from the top bar to manage leads & automations.',
          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 20),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _buildLeadCaptureForm()),
                    const SizedBox(width: 24),
                    Expanded(flex: 6, child: _buildLeadStreamAndInbox()),
                  ],
                )
              else ...[
                _buildLeadCaptureForm(),
                const SizedBox(height: 24),
                _buildLeadStreamAndInbox(),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showCredentialsDialog() {
    final waPhoneIdCtrl = TextEditingController();
    final waTokenCtrl = TextEditingController();
    final emailFromCtrl = TextEditingController();
    final emailPassCtrl = TextEditingController();

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
            const Icon(Icons.settings_outlined, color: Color(0xFF6366F1), size: 22),
            const SizedBox(width: 10),
            Text(
              'Live Channel Credentials Setup',
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
                Text(
                  'Configure your live WhatsApp & Email delivery settings below. If left empty, you can still 1-click open and send real messages via the "Open in WhatsApp App" button!',
                  style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                ),
                const Divider(height: 24, color: Color(0xFF1E293B)),
                Text(
                  '💬 WhatsApp (Meta Cloud API / Twilio):',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: waPhoneIdCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'WhatsApp Phone Number ID / Twilio Sender',
                    hintText: 'e.g. 109823485729104',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: waTokenCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Meta Permanent Access Token / Twilio Auth Token',
                    hintText: 'EAAG...',
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '✉️ Email (Gmail SMTP / Resend API):',
                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF60A5FA)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailFromCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Sender Email (e.g. orders@mycompany.com)',
                    hintText: 'yourname@gmail.com',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailPassCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Gmail App Password / Resend API Key',
                    hintText: '16-character app password or re_...',
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
              if (widget.selectedCompany == null) return;
              Navigator.pop(ctx);
              try {
                if (waPhoneIdCtrl.text.trim().isNotEmpty || waTokenCtrl.text.trim().isNotEmpty) {
                  await widget.apiService.saveIntegration(
                    companyId: widget.selectedCompany!.id,
                    channel: 'whatsapp',
                    config: {
                      'phone_number_id': waPhoneIdCtrl.text.trim(),
                      'access_token': waTokenCtrl.text.trim(),
                    },
                  );
                }
                if (emailFromCtrl.text.trim().isNotEmpty || emailPassCtrl.text.trim().isNotEmpty) {
                  final pass = emailPassCtrl.text.trim();
                  final isResend = pass.startsWith('re_');
                  await widget.apiService.saveIntegration(
                    companyId: widget.selectedCompany!.id,
                    channel: 'email',
                    config: isResend
                        ? {'from_email': emailFromCtrl.text.trim(), 'resend_api_key': pass}
                        : {
                            'smtp_host': 'smtp.gmail.com',
                            'smtp_user': emailFromCtrl.text.trim(),
                            'smtp_password': pass,
                            'smtp_port': 587,
                          },
                  );
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Channel credentials saved successfully!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save credentials: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save Credentials'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎯 Inbound Ad Leads & Autonomous Auto-Responder',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Capture customer leads from Facebook, Instagram, Google Ads & auto-send personalized WhatsApp & Email messages.',
                style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _showCredentialsDialog,
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Channel Keys'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFA5B4FC),
                side: const BorderSide(color: Color(0xFF4F46E5)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: _loadLeads,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E293B),
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeadCaptureForm() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt, color: Color(0xFF34D399), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Simulate Inbound Ad Lead Form',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Test real-time AI auto-response trained on company data',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preset Quick Fill Chips
          Text(
            'Quick Test Scenarios:',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _samplePresets.map((p) {
              return ActionChip(
                backgroundColor: const Color(0xFF1E293B),
                side: const BorderSide(color: Color(0xFF334155)),
                label: Text(
                  p['label']!,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFE2E8F0)),
                ),
                onPressed: () => _applyPreset(p),
              );
            }).toList(),
          ),
          const Divider(height: 28, color: Color(0xFF1E293B)),

          // Fields
          _buildTextField('Lead Full Name', _nameCtrl, 'e.g. Rahul Sharma', Icons.person_outline),
          const SizedBox(height: 12),
          _buildTextField('Customer WhatsApp / Phone', _phoneCtrl, 'e.g. +91 98765 43210', Icons.phone_outlined),
          const SizedBox(height: 12),
          _buildTextField('Customer Email', _emailCtrl, 'e.g. rahul@example.com', Icons.mail_outline),
          const SizedBox(height: 12),

          // Source Selector
          Text(
            'Ad Source / Campaign Platform',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F19),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSource,
                dropdownColor: const Color(0xFF0F172A),
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'instagram_ad', child: Text('📸 Instagram Sponsored Story Ad')),
                  DropdownMenuItem(value: 'facebook_ad', child: Text('👥 Facebook Lead Form Ad')),
                  DropdownMenuItem(value: 'google_ad', child: Text('🔍 Google Search Ad')),
                  DropdownMenuItem(value: 'website_form', child: Text('🌐 Direct Website Contact Form')),
                  DropdownMenuItem(value: 'whatsapp_inquiry', child: Text('💬 Inbound WhatsApp Direct Message')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedSource = val);
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          _buildTextField(
            'Customer Inquiry / Ad Click Interest',
            _interestCtrl,
            'What is the customer inquiring about?',
            Icons.chat_bubble_outline,
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _submitLead,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _isProcessing ? 'Generating & Dispatching Auto-Response...' : '⚡ Capture Lead & Dispatch Auto-Reply',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
            prefixIcon: maxLines == 1 ? Icon(icon, color: const Color(0xFF64748B), size: 18) : null,
            filled: true,
            fillColor: const Color(0xFF0B0F19),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E293B)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF10B981)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeadStreamAndInbox() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live auto response card if just dispatched
        if (_lastResult != null) ...[
          GlassCard(
            borderColor: const Color(0xFF10B981).withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Latest Live Auto-Response Dispatched',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    StatusChip(status: 'DELIVERED'),
                  ],
                ),
                const SizedBox(height: 12),
                if (_lastResult!.whatsappResponse != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0F19),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('💬 ', style: TextStyle(fontSize: 16)),
                            Expanded(
                              child: Text(
                                'WhatsApp Instant Reply (Sent to ${_phoneCtrl.text}):',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF34D399),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                              tooltip: 'Copy Message',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _lastResult!.whatsappResponse!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied WhatsApp message to clipboard!'), duration: Duration(seconds: 1)),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MarkdownText(text: _lastResult!.whatsappResponse!),
                        const SizedBox(height: 12),
                        if (_lastResult!.waLink != null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 15),
                            label: const Text('Open & Send in WhatsApp App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            onPressed: () async {
                              final uri = Uri.parse(_lastResult!.waLink!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                await launchUrl(uri);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_lastResult!.emailResponse != null) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B0F19),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('✉️ ', style: TextStyle(fontSize: 16)),
                            Expanded(
                              child: Text(
                                'Email Auto-Response (Sent to ${_emailCtrl.text}):',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF60A5FA),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF94A3B8)),
                              tooltip: 'Copy Email',
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _lastResult!.emailResponse!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Copied email to clipboard!'), duration: Duration(seconds: 1)),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MarkdownText(text: _lastResult!.emailResponse!),
                        const SizedBox(height: 12),
                        if (_lastResult!.mailtoLink != null)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.mail_outline_rounded, size: 15),
                            label: const Text('Open in Email App', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            onPressed: () async {
                              final uri = Uri.parse(_lastResult!.mailtoLink!);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                await launchUrl(uri);
                              }
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Inbound Leads Inbox
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inbox_rounded, color: Color(0xFF6366F1), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Captured Leads Inbox (${_leads.length})',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  if (_isLoadingLeads)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Color(0xFF6366F1), strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 14),

              if (_leads.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  alignment: Alignment.center,
                  child: Text(
                    'No leads captured yet. Simulate an incoming ad lead on the left!',
                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _leads.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final l = _leads[idx];
                    return _buildLeadTile(l);
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLeadTile(InboundLead l) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0F19),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        childrenPadding: const EdgeInsets.all(14),
        collapsedIconColor: const Color(0xFF94A3B8),
        iconColor: const Color(0xFF6366F1),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.person, color: Color(0xFF818CF8), size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l.name,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
            StatusChip(status: l.status.toUpperCase()),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '📱 ${l.phone ?? 'No Phone'} • ✉️ ${l.email ?? 'No Email'} • 🏷️ ${l.source}',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
          ),
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF131B2E),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Inquiry / Ad Click:',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                ),
                const SizedBox(height: 4),
                Text(
                  l.interest,
                  style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFE2E8F0)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Message timeline
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Automated Interactions (${l.interactions.length}):',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF818CF8)),
            ),
          ),
          const SizedBox(height: 8),

          if (l.interactions.isEmpty)
            Text(
              'No interactions logged yet.',
              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
            )
          else
            ...l.interactions.map((i) {
              final isWhatsApp = i.channel == 'whatsapp';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isWhatsApp
                      ? const Color(0xFF10B981).withValues(alpha: 0.08)
                      : const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isWhatsApp
                        ? const Color(0xFF10B981).withValues(alpha: 0.25)
                        : const Color(0xFF3B82F6).withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isWhatsApp ? '💬 WhatsApp Auto-Message' : '✉️ Email Auto-Message',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isWhatsApp ? const Color(0xFF34D399) : const Color(0xFF60A5FA),
                          ),
                        ),
                        Text(
                          '● ${i.status.toUpperCase()}',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF34D399),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    MarkdownText(text: i.message),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
