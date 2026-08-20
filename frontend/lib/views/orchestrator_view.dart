import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants.dart';
import '../models/agent_task.dart';
import '../models/company.dart';
import '../services/api_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/markdown_text.dart';
import '../widgets/status_chip.dart';

class OrchestratorView extends StatefulWidget {
  final ApiService apiService;
  final Company? selectedCompany;
  final VoidCallback? onRefreshCompanies;

  const OrchestratorView({
    super.key,
    required this.apiService,
    this.selectedCompany,
    this.onRefreshCompanies,
  });

  @override
  State<OrchestratorView> createState() => _OrchestratorViewState();
}

class _OrchestratorViewState extends State<OrchestratorView> {
  List<AgentTask> _tasks = [];
  bool _isLoading = false;
  bool _isOrchestrating = false;
  Timer? _pollingTimer;

  final List<String> _pipelineAgents = [
    'strategy',
    'product',
    'marketing',
    'finance',
    'social_media'
  ];

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _startPolling();
  }

  @override
  void didUpdateWidget(covariant OrchestratorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCompany?.id != widget.selectedCompany?.id) {
      _loadTasks();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) _loadTasks(silent: true);
    });
  }

  Future<void> _loadTasks({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    try {
      List<AgentTask> fetched;
      if (widget.selectedCompany != null) {
        fetched = await widget.apiService.getCompanyTasks(widget.selectedCompany!.id);
      } else {
        fetched = await widget.apiService.getAllTasks(limit: 50);
      }

      if (mounted) {
        setState(() {
          _tasks = fetched;
          _isLoading = false;
          _isOrchestrating = _tasks.any((t) => t.isRunning);
        });
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _runPipeline() async {
    if (widget.selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a company first in Company Studio')),
      );
      return;
    }

    setState(() => _isOrchestrating = true);
    try {
      await widget.apiService.runOrchestration(widget.selectedCompany!.id, _pipelineAgents);
      widget.onRefreshCompanies?.call();
      _loadTasks();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🚀 Autonomous pipeline triggered for ${widget.selectedCompany!.name}!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isOrchestrating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting pipeline: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _runSingleAgent(String agentType) async {
    if (widget.selectedCompany == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a company first in Company Studio')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Executing ${agentType.toUpperCase()} Agent...')),
    );

    try {
      await widget.apiService.runSingleAgent(widget.selectedCompany!.id, agentType);
      _loadTasks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error executing agent: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showTaskDetail(AgentTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(color: Color(0xFF1E293B)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      StatusChip(status: task.status),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task.title.isNotEmpty ? task.title : '${task.agentType.toUpperCase()} Execution Output',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Color(0xFF94A3B8)),
                        tooltip: 'Copy Output',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: task.result ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Copied task output!'), duration: Duration(seconds: 1)),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF1E293B), height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: MarkdownText(
                        text: task.result ?? task.error ?? 'No output generated yet.',
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 620;
                  return isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Multi-Agent Orchestrator',
                                    style: GoogleFonts.outfit(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_isOrchestrating)
                                  const StatusChip(status: 'running')
                                else
                                  const StatusChip(status: 'active'),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Target: $compName • Autonomous execution pipeline across Strategy, Product, Growth, Finance & Social',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6366F1),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: _isOrchestrating
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.rocket_launch_rounded, size: 20),
                                label: Text(
                                  _isOrchestrating ? 'Pipeline Running...' : 'Trigger Full Pipeline',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                onPressed: _isOrchestrating ? null : _runPipeline,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Multi-Agent Orchestrator',
                                        style: GoogleFonts.outfit(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (_isOrchestrating)
                                        const StatusChip(status: 'running')
                                      else
                                        const StatusChip(status: 'active'),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Target: $compName • Autonomous execution pipeline across Strategy, Product, Growth, Finance & Social',
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      color: const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: _isOrchestrating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.rocket_launch_rounded, size: 20),
                              label: Text(
                                _isOrchestrating ? 'Pipeline Running...' : 'Trigger Full Pipeline',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              onPressed: _isOrchestrating ? null : _runPipeline,
                            ),
                          ],
                        );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Pipeline Stages Visual Grid
            Text(
              'Autonomous Agent Pipeline Stages',
              style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const SizedBox(height: 12),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 800;
                final isNarrowMobile = constraints.maxWidth < 400;
                final itemWidth = isWide
                    ? (constraints.maxWidth - 48) / 5
                    : isNarrowMobile
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _pipelineAgents.map((agentKey) {
                    final role = AppConstants.agentRoles.firstWhere(
                      (r) => r['id'] == agentKey,
                      orElse: () => AppConstants.agentRoles.first,
                    );
                    final color = role['color'] as Color;
                    final matchingTask = _tasks.where((t) => t.agentType == agentKey).toList();
                    final latestTask = matchingTask.isNotEmpty ? matchingTask.first : null;

                    return SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: latestTask != null && latestTask.isRunning
                                ? color
                                : const Color(0xFF1E293B),
                            width: latestTask != null && latestTask.isRunning ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(role['icon'] as IconData, color: color, size: 18),
                                ),
                                if (latestTask != null)
                                  StatusChip(status: latestTask.status, compact: true)
                                else
                                  const StatusChip(status: 'pending', compact: true),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              role['name'] as String,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              role['desc'] as String,
                              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: color.withValues(alpha: 0.5)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: latestTask != null && latestTask.isRunning
                                    ? null
                                    : () => _runSingleAgent(agentKey),
                                child: Text(
                                  latestTask != null && latestTask.isRunning ? 'Running...' : 'Run Agent',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 28),

            // Execution Logs & Task Artifacts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Execution Logs & Output Artifacts',
                  style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
                  onPressed: () => _loadTasks(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_isLoading && _tasks.isEmpty)
              const Center(child: CircularProgressIndicator())
            else if (_tasks.isEmpty)
              GlassCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.hub_outlined, size: 48, color: Color(0xFF64748B)),
                      const SizedBox(height: 12),
                      Text(
                        'No agent tasks recorded yet',
                        style: GoogleFonts.outfit(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tap "Trigger Full Pipeline" above to run autonomous agents for this enterprise.',
                        style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tasks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  final role = AppConstants.agentRoles.firstWhere(
                    (r) => r['id'] == task.agentType,
                    orElse: () => AppConstants.agentRoles.first,
                  );
                  final color = role['color'] as Color;

                  return GlassCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () => _showTaskDetail(task),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(role['icon'] as IconData, color: color, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      task.title.isNotEmpty ? task.title : (role['name'] as String),
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusChip(status: task.status, compact: true),
                                  if (task.createdAt != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '${task.createdAt!.hour.toString().padLeft(2, '0')}:${task.createdAt!.minute.toString().padLeft(2, '0')}',
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (task.result ?? task.error ?? 'Execution in progress...').replaceAll('\n', ' '),
                                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF64748B)),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
