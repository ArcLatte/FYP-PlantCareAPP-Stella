import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../models/scan.dart';
import '../../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScanResult> _scans = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final scans = await ApiService.getAllScans();
      setState(() {
        _scans = scans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteScan(int scanId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text(
          'Delete Scan',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Are you sure you want to delete this scan?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteScan(scanId);
      _loadHistory();
    }
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatLabel(String label) {
    return label
        .replaceAll('_', ' ')
        .replaceAll('Tomato ', '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _scans.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        size: 64,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No scans yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your scan history will appear here',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHistory,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: _scans.length,
                    itemBuilder: (context, index) {
                      final scan = _scans[index];
                      final isHealthy = scan.confirmedDisease
                              ?.toLowerCase()
                              .contains('healthy') ==
                          true;
                      final isPending = scan.confirmedDisease == null;

                      return Dismissible(
                        key: Key(scan.id.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.error,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          await _deleteScan(scan.id);
                          return false;
                        },
                        child: GestureDetector(
                          onTap: () => context.push('/result/${scan.id}'),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: AppColors.cardBorder),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.cardShadow,
                                  blurRadius: 12,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: isPending
                                        ? AppColors.textMuted.withValues(alpha: 0.15)
                                        : isHealthy
                                            ? AppColors.success
                                                .withValues(alpha: 0.15)
                                            : AppColors.amber
                                                .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isPending
                                        ? Icons.hourglass_empty_rounded
                                        : isHealthy
                                            ? Icons.favorite_rounded
                                            : Icons.warning_amber_rounded,
                                    color: isPending
                                        ? AppColors.textMuted
                                        : isHealthy
                                            ? AppColors.success
                                            : AppColors.amber,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        scan.confirmedDisease != null
                                            ? _formatLabel(
                                                scan.confirmedDisease!)
                                            : 'Pending confirmation',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(scan.createdAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}