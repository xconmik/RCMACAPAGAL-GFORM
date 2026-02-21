import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_data.dart';
import '../services/admin_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  static const List<String> _branches = [
    'ALL',
    'Bulacan',
    'DSO Talavera',
    'DSO Tarlac',
    'DSO Pampanga',
    'DSO Villasis',
    'DSO Bantay',
  ];

  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();

  String _selectedBranch = 'ALL';
  String _searchQuery = '';
  _HistoryRange _historyRange = _HistoryRange.last30Days;
  int _currentLimit = 200;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  AdminDashboardData? _dashboard;
  DateTime? _lastRefreshedAt;

  final DateFormat _displayDateFormat = DateFormat('MMM d, y h:mm a');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await _adminService.fetchDashboardData(
        branch: _selectedBranch,
        limit: _currentLimit,
      );

      if (!mounted) return;
      setState(() {
        _dashboard = data;
        _lastRefreshedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dashboard Filters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          )),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedBranch,
                              decoration: InputDecoration(
                                labelText: 'Branch',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: _branches
                                  .map(
                                    (branch) => DropdownMenuItem<String>(
                                      value: branch,
                                      child: Text(branch),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() {
                                  _selectedBranch = value;
                                  _currentLimit = 200;
                                });
                                _loadData();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                labelText: 'Search outlet / owner',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.trim().toLowerCase();
                                });
                              },
                              onSubmitted: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _lastRefreshedAt == null
                            ? 'Last updated: -'
                            : 'Last updated: ${_displayDateFormat.format(_lastRefreshedAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _dashboard?.scriptTimestamp.trim().isNotEmpty == true
                            ? 'Script time: ${_formatTimestamp(_dashboard!.scriptTimestamp)}'
                            : 'Script time: -',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 42),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: _loadData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: _buildContent(_dashboard),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(AdminDashboardData? dashboard) {
    if (dashboard == null) {
      return const Center(child: Text('No data available.'));
    }

    final filteredSubmissions = dashboard.recentSubmissions.where((submission) {
      if (_searchQuery.isEmpty) return true;
      final text = '${submission.outletCode} ${submission.storeOwnerName} ${submission.signageName}'
          .toLowerCase();
      return text.contains(_searchQuery);
    }).toList();

    final historyFilteredSubmissions = _applyHistoryFilter(filteredSubmissions);

    final activeBranchCount =
        dashboard.branches.where((branch) => branch.totalRows > 0).length;
    final todayCount = historyFilteredSubmissions
        .where((item) => _isToday(_parseDate(item.timestamp)))
        .length;
    final topBranch = _getTopBranch(dashboard.branches);

    final quantityStats = _calculateQuantityStats(historyFilteredSubmissions);

    return ListView(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildKpiCard(
              label: 'Total Submissions',
              value: '${dashboard.totalSubmissions}',
              icon: Icons.assignment_turned_in_outlined,
            ),
            _buildKpiCard(
              label: 'Active Branches',
              value: '$activeBranchCount',
              icon: Icons.store_mall_directory_outlined,
            ),
            _buildKpiCard(
              label: 'Today (Visible)',
              value: '$todayCount',
              icon: Icons.today_outlined,
            ),
            _buildKpiCard(
              label: 'Top Branch',
              value: topBranch,
              icon: Icons.emoji_events_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionTitle('Branch Performance'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: dashboard.branches.map((item) {
                final maxRows = dashboard.branches
                    .fold<int>(1, (max, branch) => branch.totalRows > max ? branch.totalRows : max);
                final progress = maxRows == 0 ? 0.0 : item.totalRows / maxRows;
                final isSelected = _selectedBranch == item.branch;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      if (_selectedBranch == item.branch) return;
                      setState(() {
                        _selectedBranch = item.branch;
                        _currentLimit = 200;
                      });
                      await _loadData();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                          width: isSelected ? 1.5 : 1,
                        ),
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.white,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.branch,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              Text(
                                '${item.totalRows}',
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Click to view entries',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionTitle('Quantity Insights'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _buildKpiCard(
              label: 'Signage Total',
              value: '${quantityStats.signageTotal}',
              icon: Icons.border_style_outlined,
            ),
            _buildKpiCard(
              label: 'Awnings Total',
              value: '${quantityStats.awningTotal}',
              icon: Icons.wb_shade_outlined,
            ),
            _buildKpiCard(
              label: 'Flange Total',
              value: '${quantityStats.flangeTotal}',
              icon: Icons.tab_outlined,
            ),
            _buildKpiCard(
              label: 'Refused Entries',
              value: '${quantityStats.refusedCount}',
              icon: Icons.block_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionTitle(
          'Recent Submissions (${historyFilteredSubmissions.length})',
        ),
        const SizedBox(height: 8),
        _buildHistoryRangeChips(),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: historyFilteredSubmissions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No submissions match your filters.'),
                )
              : _buildSubmissionTable(historyFilteredSubmissions),
        ),
        const SizedBox(height: 14),
        _buildSectionTitle('Branch Entries'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: _selectedBranch == 'ALL'
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Click a branch above to view all entries with images.'),
                )
              : _buildBranchEntries(historyFilteredSubmissions),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: _buildLoadMoreButton(dashboard, historyFilteredSubmissions),
        ),
        const SizedBox(height: 14),
        _buildSectionTitle('History Timeline'),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: historyFilteredSubmissions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No history entries available for this filter.'),
                )
              : _buildHistoryTimeline(historyFilteredSubmissions),
        ),
      ],
    );
  }

  Widget _buildLoadMoreButton(
    AdminDashboardData dashboard,
    List<AdminSubmission> historyFilteredSubmissions,
  ) {
    final bool hasMore = dashboard.totalSubmissions > dashboard.recentSubmissions.length;

    if (!hasMore) {
      return const Text(
        'All available history loaded.',
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54),
      );
    }

    return FilledButton.icon(
      onPressed: _isLoadingMore
          ? null
          : () async {
              setState(() {
                _isLoadingMore = true;
                _currentLimit += 200;
              });

              await _loadData();

              if (!mounted) return;
              setState(() {
                _isLoadingMore = false;
              });
            },
      icon: _isLoadingMore
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.expand_more),
      label: Text(
        _isLoadingMore
            ? 'Loading...'
            : 'Load More History (${historyFilteredSubmissions.length}/${dashboard.totalSubmissions})',
      ),
    );
  }

  Widget _buildHistoryRangeChips() {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: const Text('7 Days'),
          selected: _historyRange == _HistoryRange.last7Days,
          onSelected: (_) {
            setState(() {
              _historyRange = _HistoryRange.last7Days;
            });
          },
        ),
        ChoiceChip(
          label: const Text('30 Days'),
          selected: _historyRange == _HistoryRange.last30Days,
          onSelected: (_) {
            setState(() {
              _historyRange = _HistoryRange.last30Days;
            });
          },
        ),
        ChoiceChip(
          label: const Text('All'),
          selected: _historyRange == _HistoryRange.all,
          onSelected: (_) {
            setState(() {
              _historyRange = _HistoryRange.all;
            });
          },
        ),
      ],
    );
  }

  Widget _buildHistoryTimeline(List<AdminSubmission> submissions) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: submissions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = submissions[index];
        final parsed = _parseDate(item.timestamp);
        final dateText = parsed == null
          ? _formatTimestamp(item.scriptTimestamp)
          : _displayDateFormat.format(parsed.toLocal());

        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(
            item.outletCode.isEmpty ? '(No outlet code)' : item.outletCode,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${item.branch} • ${item.storeOwnerName}\n$dateText',
          ),
          isThreeLine: true,
          trailing: Text(
            'S:${item.signageQuantity} A:${item.awningQuantity} F:${item.flangeQuantity}',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }

  Widget _buildBranchEntries(List<AdminSubmission> submissions) {
    if (submissions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No entries available for this branch and filter.'),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: submissions.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = submissions[index];

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.outletCode.isEmpty ? '(No outlet code)' : entry.outletCode,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text('Timestamp: ${_formatEntryTimestamp(entry)}'),
              Text('Submitted At: ${entry.submittedAt.isEmpty ? '-' : _formatTimestamp(entry.submittedAt)}'),
              Text('Full Name: ${entry.fullName.isEmpty ? '-' : entry.fullName}'),
              Text('Brand: ${entry.brands.isEmpty ? '-' : entry.brands}'),
              Text('Owner: ${entry.storeOwnerName}'),
              Text('Signage Name: ${entry.signageName}'),
              Text(
                'Quantity - Signage: ${entry.signageQuantity}, Awnings: ${entry.awningQuantity}, Flange: ${entry.flangeQuantity}',
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildImageThumb('Before', entry.beforeImageDriveUrl),
                  _buildImageThumb('After', entry.afterImageDriveUrl),
                  _buildImageThumb('Completion', entry.completionImageDriveUrl),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageThumb(String label, String url) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 180,
              height: 100,
              color: Colors.grey.shade100,
              child: url.trim().isEmpty
                  ? const Center(child: Text('No image'))
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                        child: Text('Image unavailable'),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<AdminSubmission> _applyHistoryFilter(List<AdminSubmission> submissions) {
    if (_historyRange == _HistoryRange.all) return submissions;

    final now = DateTime.now();
    final days = _historyRange == _HistoryRange.last7Days ? 7 : 30;
    final cutoff = now.subtract(Duration(days: days));

    return submissions.where((submission) {
      final date = _parseDate(submission.timestamp);
      if (date == null) return false;
      return date.isAfter(cutoff) || date.isAtSameMomentAs(cutoff);
    }).toList();
  }

  Widget _buildSubmissionTable(List<AdminSubmission> submissions) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w800),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Branch')),
          DataColumn(label: Text('Full Name')),
          DataColumn(label: Text('Outlet Code')),
          DataColumn(label: Text('Brands')),
          DataColumn(label: Text('Signage Name')),
          DataColumn(label: Text('Owner')),
          DataColumn(label: Text('Signage')),
          DataColumn(label: Text('Awnings')),
          DataColumn(label: Text('Flange')),
        ],
        rows: submissions.map((submission) {
          final parsed = _parseDate(submission.timestamp);
            final dateText = parsed == null
                ? _formatTimestamp(submission.scriptTimestamp)
                : _displayDateFormat.format(parsed.toLocal());

          return DataRow(
            cells: [
              DataCell(Text(dateText)),
              DataCell(Text(submission.branch)),
              DataCell(Text(submission.fullName)),
              DataCell(Text(submission.outletCode)),
              DataCell(Text(submission.brands)),
              DataCell(Text(submission.signageName)),
              DataCell(Text(submission.storeOwnerName)),
              DataCell(Text(submission.signageQuantity)),
              DataCell(Text(submission.awningQuantity)),
              DataCell(Text(submission.flangeQuantity)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  _QuantityStats _calculateQuantityStats(List<AdminSubmission> submissions) {
    var signageTotal = 0;
    var awningTotal = 0;
    var flangeTotal = 0;
    var refusedCount = 0;

    for (final submission in submissions) {
      signageTotal += _parseQuantity(submission.signageQuantity);
      awningTotal += _parseQuantity(submission.awningQuantity);
      flangeTotal += _parseQuantity(submission.flangeQuantity);

      if (_isRefused(submission.signageQuantity) ||
          _isRefused(submission.awningQuantity) ||
          _isRefused(submission.flangeQuantity)) {
        refusedCount += 1;
      }
    }

    return _QuantityStats(
      signageTotal: signageTotal,
      awningTotal: awningTotal,
      flangeTotal: flangeTotal,
      refusedCount: refusedCount,
    );
  }

  int _parseQuantity(String value) {
    return int.tryParse(value.trim()) ?? 0;
  }

  bool _isRefused(String value) {
    return value.trim().toUpperCase() == 'REFUSED';
  }

  String _getTopBranch(List<BranchSummary> branches) {
    if (branches.isEmpty) return '-';
    final sorted = [...branches]..sort((a, b) => b.totalRows.compareTo(a.totalRows));
    if (sorted.first.totalRows == 0) return '-';
    return sorted.first.branch;
  }

  DateTime? _parseDate(String input) {
    if (input.trim().isEmpty) return null;
    return DateTime.tryParse(input);
  }

  String _formatTimestamp(String input) {
    final parsed = _parseDate(input);
    if (parsed == null) return input;
    return _displayDateFormat.format(parsed.toLocal());
  }

  String _formatEntryTimestamp(AdminSubmission entry) {
    if (entry.scriptTimestamp.trim().isNotEmpty) {
      return _formatTimestamp(entry.scriptTimestamp);
    }
    return _formatTimestamp(entry.timestamp);
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }
}

class _QuantityStats {
  const _QuantityStats({
    required this.signageTotal,
    required this.awningTotal,
    required this.flangeTotal,
    required this.refusedCount,
  });

  final int signageTotal;
  final int awningTotal;
  final int flangeTotal;
  final int refusedCount;
}

enum _HistoryRange {
  last7Days,
  last30Days,
  all,
}
