import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_data.dart';
import '../services/admin_service.dart';
import '../services/allocation_service.dart';

enum _AdminMenu { dashboard, entries, allocations, encoderArea }
enum _HistoryRange { last7Days, last30Days, all }

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

  static const List<String> _brandOptions = ['MIGHTY', 'CAMEL', 'WINSTON'];

  final AdminService _adminService = AdminService();
  final AllocationService _allocationService = AllocationService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _allocationAllController = TextEditingController();
  final Map<String, TextEditingController> _allocationControllers = {};

  _AdminMenu _activeMenu = _AdminMenu.dashboard;
  _HistoryRange _historyRange = _HistoryRange.last30Days;

  String _selectedBranch = 'ALL';
  String _searchQuery = '';

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isAllocationEditLocked = false;
  String? _error;
  final Set<String> _deletingEntryKeys = <String>{};

  int _currentLimit = 200;

  AdminDashboardData? _dashboard;
  DateTime? _lastRefreshedAt;
  Map<String, Map<String, int>> _allocations = {};

  final DateFormat _displayDateFormat = DateFormat('MMM d, y h:mm a');

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _allocationAllController.dispose();
    for (final controller in _allocationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    await _loadAllocations();
    await _loadData();
  }

  Future<void> _loadAllocations() async {
    final allocations = await _allocationService.loadAllocations(
      branches: _branches.where((branch) => branch != 'ALL').toList(),
      brands: _brandOptions,
    );

    if (!mounted) return;

    setState(() {
      _allocations = allocations;
      _syncAllocationControllers();
    });
  }

  void _syncAllocationControllers() {
    for (final branch in _allocations.keys) {
      for (final brand in _brandOptions) {
        final key = '$branch|$brand';
        final target = _allocations[branch]?[brand] ?? 0;
        final text = target == 0 ? '' : '$target';

        if (_allocationControllers.containsKey(key)) {
          final ctrl = _allocationControllers[key]!;
          if (ctrl.text != text) ctrl.text = text;
        } else {
          _allocationControllers[key] = TextEditingController(text: text);
        }
      }
    }
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

      await _ensureAllocationBranches(_extractBranchesFromData(data));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<String> _extractBranchesFromData(AdminDashboardData data) {
    final branches = <String>{..._branches.where((branch) => branch != 'ALL')};

    for (final branch in data.branches) {
      final name = branch.branch.trim();
      if (name.isNotEmpty) branches.add(name);
    }

    for (final item in data.recentSubmissions) {
      final name = item.branch.trim();
      if (name.isNotEmpty) branches.add(name);
    }

    final list = branches.toList()..sort();
    return list;
  }

  List<String> _branchOptions({bool includeAll = true}) {
    final dynamicBranches = _dashboard == null
        ? _branches.where((branch) => branch != 'ALL').toList()
        : _extractBranchesFromData(_dashboard!);

    return includeAll ? ['ALL', ...dynamicBranches] : dynamicBranches;
  }

  Future<void> _ensureAllocationBranches(List<String> branches) async {
    var changed = false;

    for (final branch in branches) {
      _allocations.putIfAbsent(branch, () {
        changed = true;
        return <String, int>{};
      });

      for (final brand in _brandOptions) {
        _allocations[branch]!.putIfAbsent(brand, () {
          changed = true;
          return 0;
        });
      }
    }

    if (!changed) return;

    await _allocationService.saveAllocations(_allocations);
    if (!mounted) return;

    setState(() {
      _syncAllocationControllers();
    });
  }

  Future<void> _saveAllocations() async {
    _syncAllocationsFromControllers();
    await _allocationService.saveAllocations(_allocations);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Allocation saved.')),
    );
  }

  Future<void> _saveAllocationsAndLock() async {
    await _saveAllocations();
    if (!mounted) return;
    setState(() {
      _isAllocationEditLocked = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Allocation saved and locked.')),
    );
  }

  void _syncAllocationsFromControllers() {
    for (final entry in _allocationControllers.entries) {
      final keyParts = entry.key.split('|');
      if (keyParts.length != 2) continue;

      final branch = keyParts[0];
      final brand = keyParts[1];
      final value = int.tryParse(entry.value.text.trim()) ?? 0;

      _allocations[branch] ??= <String, int>{};
      _allocations[branch]![brand] = value;
    }
  }

  void _applyAllocationToAll() {
    final value = int.tryParse(_allocationAllController.text.trim());
    if (value == null || value < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid non-negative number for all allocation.')),
      );
      return;
    }

    for (final branch in _allocations.keys) {
      _allocations[branch] ??= <String, int>{};
      for (final brand in _brandOptions) {
        _allocations[branch]![brand] = value;
        final key = '$branch|$brand';
        final text = value == 0 ? '' : '$value';
        if (_allocationControllers.containsKey(key)) {
          _allocationControllers[key]!.text = text;
        } else {
          _allocationControllers[key] = TextEditingController(text: text);
        }
      }
    }

    setState(() {
      _isAllocationEditLocked = true;
    });
  }

  void _enableAllocationEdit() {
    setState(() {
      _isAllocationEditLocked = false;
    });
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
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Menu',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              _menuTile('Dashboard', _AdminMenu.dashboard),
              _menuTile('Branch Entries', _AdminMenu.entries),
              _menuTile('Allocations', _AdminMenu.allocations),
              _menuTile('ENCODER AREA', _AdminMenu.encoderArea),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildFilterCard(),
              const SizedBox(height: 12),
              if (_isLoading)
                const Expanded(child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              else
                Expanded(
                  child: _buildActiveView(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile(String label, _AdminMenu menu) {
    final selected = _activeMenu == menu;

    return ListTile(
      selected: selected,
      title: Text(label),
      onTap: () {
        setState(() {
          _activeMenu = menu;
        });
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildFilterCard() {
    final branchOptions = _branchOptions();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filters',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedBranch,
                    decoration: const InputDecoration(labelText: 'Branch'),
                    items: branchOptions
                        .map((branch) => DropdownMenuItem(
                              value: branch,
                              child: Text(branch),
                            ))
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
                    decoration: const InputDecoration(
                      labelText: 'Search outlet / owner',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _lastRefreshedAt == null
                  ? 'Last updated: -'
                  : 'Last updated: ${_displayDateFormat.format(_lastRefreshedAt!)}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 4),
            Text(
              _dashboard?.scriptTimestamp.trim().isNotEmpty == true
                  ? 'Script time: ${_formatTimestamp(_dashboard!.scriptTimestamp)}'
                  : 'Script time: -',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveView() {
    final dashboard = _dashboard;
    if (dashboard == null) return const Center(child: Text('No data available.'));

    switch (_activeMenu) {
      case _AdminMenu.dashboard:
        return _buildDashboardView(dashboard);
      case _AdminMenu.entries:
        return _buildEntriesView(dashboard);
      case _AdminMenu.allocations:
        return _buildAllocationsView(dashboard);
      case _AdminMenu.encoderArea:
        return _buildEncoderAreaView(dashboard);
    }
  }

  Widget _buildDashboardView(AdminDashboardData dashboard) {
    final filtered = _filteredSubmissions(dashboard.recentSubmissions);
    final historyFiltered = _applyHistoryFilter(filtered);

    final activeBranchCount =
        dashboard.branches.where((branch) => branch.totalRows > 0).length;

    return ListView(
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _kpiCard('Total Submissions', '${dashboard.totalSubmissions}', Icons.assignment_turned_in_outlined),
            _kpiCard('Active Branches', '$activeBranchCount', Icons.store_mall_directory_outlined),
            _kpiCard('Visible Rows', '${historyFiltered.length}', Icons.table_rows_outlined),
          ],
        ),
        const SizedBox(height: 14),
        const Text('History Range', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('7 Days'),
              selected: _historyRange == _HistoryRange.last7Days,
              onSelected: (_) => setState(() => _historyRange = _HistoryRange.last7Days),
            ),
            ChoiceChip(
              label: const Text('30 Days'),
              selected: _historyRange == _HistoryRange.last30Days,
              onSelected: (_) => setState(() => _historyRange = _HistoryRange.last30Days),
            ),
            ChoiceChip(
              label: const Text('All'),
              selected: _historyRange == _HistoryRange.all,
              onSelected: (_) => setState(() => _historyRange = _HistoryRange.all),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: historyFiltered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No submissions found.'),
                )
              : _buildSubmissionTable(historyFiltered),
        ),
      ],
    );
  }

  Widget _buildEntriesView(AdminDashboardData dashboard) {
    final filtered = _applyHistoryFilter(_filteredSubmissions(dashboard.recentSubmissions));

    return ListView(
      children: [
        const Text('Branch Performance', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: dashboard.branches.map((item) {
                final isSelected = _selectedBranch == item.branch;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
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
                        color: isSelected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(item.branch,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Text('${item.totalRows}',
                              style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Entries', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          child: _selectedBranch == 'ALL'
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Select a branch above to view all entries.'),
                )
              : _buildBranchEntries(filtered),
        ),
        const SizedBox(height: 8),
        _buildLoadMoreButton(dashboard, filtered.length),
      ],
    );
  }

  Widget _buildAllocationsView(AdminDashboardData dashboard) {
    final actual = _computeActualBrandCounts(dashboard.recentSubmissions);
    final branchOptions = _branchOptions(includeAll: false);

    return ListView(
      children: [
        const Text(
          'Branch Brand Allocation',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _allocationAllController,
                    keyboardType: TextInputType.number,
                    enabled: !_isAllocationEditLocked,
                    decoration: const InputDecoration(
                      labelText: 'Allocation for all',
                      hintText: 'e.g. 100',
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isAllocationEditLocked ? null : _applyAllocationToAll,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Apply All & Lock'),
                ),
                FilledButton.icon(
                  onPressed: _saveAllocationsAndLock,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Allocation & Lock'),
                ),
                OutlinedButton.icon(
                  onPressed: _isAllocationEditLocked ? _enableAllocationEdit : null,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Enable Edit'),
                ),
                Text(
                  _isAllocationEditLocked ? 'Status: Locked' : 'Status: Editable',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _isAllocationEditLocked ? Colors.orange.shade800 : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...branchOptions.map((branch) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(branch,
                      style:
                          const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  ..._brandOptions.map((brand) {
                    final key = '$branch|$brand';
                    final controller = _allocationControllers[key] ?? TextEditingController();
                    _allocationControllers.putIfAbsent(key, () => controller);
                    final actualValue = actual[branch]?[brand] ?? 0;
                    final targetValue = _allocations[branch]?[brand] ?? 0;
                    final remainingValue = targetValue - actualValue;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              brand,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              enabled: !_isAllocationEditLocked,
                              decoration: const InputDecoration(
                                labelText: 'Allocation',
                              ),
                              onChanged: (value) {
                                final parsed = int.tryParse(value.trim()) ?? 0;
                                setState(() {
                                  _allocations[branch] ??= {};
                                  _allocations[branch]![brand] = parsed;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text('Installed: $actualValue'),
                          const SizedBox(width: 10),
                          Text(
                            'Remaining: $remainingValue',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: remainingValue < 0
                                  ? Colors.red
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEncoderAreaView(AdminDashboardData dashboard) {
    final branchOptions = _branchOptions(includeAll: false);
    final stats = _computeEncoderStats(dashboard.recentSubmissions);
    final branchesToShow = _selectedBranch == 'ALL'
        ? branchOptions
        : branchOptions.where((branch) => branch == _selectedBranch).toList();

    if (branchesToShow.isEmpty) {
      return const Center(child: Text('No encoder data available.'));
    }

    return ListView(
      children: [
        const Text(
          'Encoder Area',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        ...branchesToShow.map((branch) {
          final branchStats = stats[branch] ?? _emptyEncoderStats();

          final totalAllocation = _brandOptions
              .map((brand) => _allocations[branch]?[brand] ?? 0)
              .fold<int>(0, (sum, value) => sum + value);
          final totalInstalled = _brandOptions
              .map((brand) => branchStats[brand]?.installedCount ?? 0)
              .fold<int>(0, (sum, value) => sum + value);
          final totalBalance = totalAllocation - totalInstalled;

          final totalSignage = _brandOptions
              .map((brand) => branchStats[brand]?.signageTotal ?? 0)
              .fold<int>(0, (sum, value) => sum + value);
          final totalAwning = _brandOptions
              .map((brand) => branchStats[brand]?.awningTotal ?? 0)
              .fold<int>(0, (sum, value) => sum + value);
          final totalFlange = _brandOptions
              .map((brand) => branchStats[brand]?.flangeTotal ?? 0)
              .fold<int>(0, (sum, value) => sum + value);

          final dailySignage = _brandOptions
              .map((brand) => branchStats[brand]?.dailySignage ?? 0)
              .fold<int>(0, (sum, value) => sum + value);
          final dailyAwning = _brandOptions
              .map((brand) => branchStats[brand]?.dailyAwning ?? 0)
              .fold<int>(0, (sum, value) => sum + value);
          final dailyFlange = _brandOptions
              .map((brand) => branchStats[brand]?.dailyFlange ?? 0)
              .fold<int>(0, (sum, value) => sum + value);

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _miniStat('Total Allocation', '$totalAllocation'),
                      _miniStat('Total Installed', '$totalInstalled'),
                      _miniStat(
                        'Total Balance',
                        '$totalBalance',
                        valueColor: totalBalance < 0 ? Colors.red : Colors.green.shade700,
                      ),
                      _miniStat('Total Qty Signage', '$totalSignage'),
                      _miniStat('Total Qty Awning', '$totalAwning'),
                      _miniStat('Total Qty Flange', '$totalFlange'),
                      _miniStat('Daily Signage', '$dailySignage'),
                      _miniStat('Daily Awning', '$dailyAwning'),
                      _miniStat('Daily Flange', '$dailyFlange'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w800),
                      columns: const [
                        DataColumn(label: Text('Brand')),
                        DataColumn(label: Text('Allocation')),
                        DataColumn(label: Text('Installed')),
                        DataColumn(label: Text('Balance')),
                        DataColumn(label: Text('Qty Signage')),
                        DataColumn(label: Text('Qty Awning')),
                        DataColumn(label: Text('Qty Flange')),
                        DataColumn(label: Text('Daily Signage')),
                        DataColumn(label: Text('Daily Awning')),
                        DataColumn(label: Text('Daily Flange')),
                      ],
                      rows: _brandOptions.map((brand) {
                        final item = branchStats[brand] ?? const _EncoderMetrics();
                        final allocation = _allocations[branch]?[brand] ?? 0;
                        final balance = allocation - item.installedCount;

                        return DataRow(
                          cells: [
                            DataCell(Text(brand)),
                            DataCell(Text('$allocation')),
                            DataCell(Text('${item.installedCount}')),
                            DataCell(Text('$balance')),
                            DataCell(Text('${item.signageTotal}')),
                            DataCell(Text('${item.awningTotal}')),
                            DataCell(Text('${item.flangeTotal}')),
                            DataCell(Text('${item.dailySignage}')),
                            DataCell(Text('${item.dailyAwning}')),
                            DataCell(Text('${item.dailyFlange}')),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _miniStat(String label, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton(AdminDashboardData dashboard, int visibleCount) {
    final hasMore = dashboard.totalSubmissions > dashboard.recentSubmissions.length;
    if (!hasMore) {
      return const Text('All available history loaded.',
          style: TextStyle(color: Colors.black54));
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
            : 'Load More History ($visibleCount/${dashboard.totalSubmissions})',
      ),
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
        final entryKey = entry.entryId.isNotEmpty
            ? entry.entryId
            : '${entry.branch}:${entry.rowNumber ?? -1}:${entry.timestamp}';
        final isDeleting = _deletingEntryKeys.contains(entryKey);
        final canDelete = entry.rowNumber != null && entry.rowNumber! > 1;
        final hasImages = entry.beforeImageDriveUrl.trim().isNotEmpty ||
          entry.afterImageDriveUrl.trim().isNotEmpty ||
          entry.completionImageDriveUrl.trim().isNotEmpty;

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.outletCode.isEmpty ? '(No outlet code)' : entry.outletCode,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: hasImages ? 'View images' : 'No images available',
                    onPressed: hasImages ? () => _showImagesDialog(entry) : null,
                    icon: const Icon(Icons.photo_library_outlined),
                  ),
                  IconButton(
                    tooltip: canDelete
                        ? 'Delete this entry'
                        : 'Cannot delete this entry',
                    onPressed: !canDelete || isDeleting
                        ? null
                        : () => _confirmDeleteEntry(entry, entryKey),
                    icon: isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    color: Colors.red,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Timestamp: ${_formatEntryTimestamp(entry)}'),
              Text('Installer Name: ${entry.fullName.isEmpty ? '-' : entry.fullName}'),
              Text('Brand: ${entry.brands.isEmpty ? '-' : entry.brands}'),
              Text('Owner: ${entry.storeOwnerName}'),
              Text('Signage Name: ${entry.signageName}'),
              Text(
                'Quantity - Signage: ${entry.signageQuantity}, Awnings: ${entry.awningQuantity}, Flange: ${entry.flangeQuantity}',
              ),
              if (entry.rowNumber != null)
                Text(
                  'Sheet row: ${entry.rowNumber}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showImagesDialog(AdminSubmission entry) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Entry Images'),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImagePreviewTile('Before', entry.beforeImageDriveUrl),
                  const SizedBox(height: 12),
                  _buildImagePreviewTile('After', entry.afterImageDriveUrl),
                  const SizedBox(height: 12),
                  _buildImagePreviewTile('Completion', entry.completionImageDriveUrl),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildImagePreviewTile(String label, String url) {
    final normalized = url.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        if (normalized.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('No image URL available.'),
          )
        else
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              normalized,
              fit: BoxFit.cover,
              height: 180,
              width: double.infinity,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 180,
                  alignment: Alignment.center,
                  color: Colors.grey.shade100,
                  child: const CircularProgressIndicator(),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 180,
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  alignment: Alignment.centerLeft,
                  color: Colors.grey.shade100,
                  child: const Text('Unable to load image. Check file sharing permissions.'),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _confirmDeleteEntry(AdminSubmission entry, String entryKey) async {
    final rowNumber = entry.rowNumber;
    if (rowNumber == null || rowNumber <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to delete this entry. Missing row reference.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text(
          'Delete this entry for ${entry.outletCode.isEmpty ? 'this outlet' : entry.outletCode}? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _deletingEntryKeys.add(entryKey);
    });

    try {
      await _adminService.deleteEntry(branch: entry.branch, rowNumber: rowNumber);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry deleted successfully.')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _deletingEntryKeys.remove(entryKey);
      });
    }
  }

  Widget _buildSubmissionTable(List<AdminSubmission> submissions) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingTextStyle: const TextStyle(fontWeight: FontWeight.w800),
        columns: const [
          DataColumn(label: Text('Date')),
          DataColumn(label: Text('Branch')),
          DataColumn(label: Text('Installer Name')),
          DataColumn(label: Text('Outlet Code')),
          DataColumn(label: Text('Brands')),
          DataColumn(label: Text('Signage Name')),
          DataColumn(label: Text('Owner')),
          DataColumn(label: Text('Signage')),
          DataColumn(label: Text('Awnings')),
          DataColumn(label: Text('Flange')),
        ],
        rows: submissions.map((submission) {
          final dateText = _formatTimestamp(
            submission.scriptTimestamp.isNotEmpty
                ? submission.scriptTimestamp
                : submission.timestamp,
          );

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

  Widget _kpiCard(String label, String value, IconData icon) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
    );
  }

  List<AdminSubmission> _filteredSubmissions(List<AdminSubmission> submissions) {
    return submissions.where((submission) {
      if (_searchQuery.isEmpty) return true;
      final text =
          '${submission.outletCode} ${submission.storeOwnerName} ${submission.signageName} ${submission.fullName}'
              .toLowerCase();
      return text.contains(_searchQuery);
    }).toList();
  }

  List<AdminSubmission> _applyHistoryFilter(List<AdminSubmission> submissions) {
    if (_historyRange == _HistoryRange.all) return submissions;

    final now = DateTime.now();
    final days = _historyRange == _HistoryRange.last7Days ? 7 : 30;
    final cutoff = now.subtract(Duration(days: days));

    return submissions.where((submission) {
      final date = DateTime.tryParse(submission.timestamp);
      if (date == null) return false;
      return date.isAfter(cutoff) || date.isAtSameMomentAs(cutoff);
    }).toList();
  }

  Map<String, Map<String, int>> _computeActualBrandCounts(
    List<AdminSubmission> submissions,
  ) {
    final result = <String, Map<String, int>>{};

    for (final branch in _branchOptions(includeAll: false)) {
      result[branch] = {for (final brand in _brandOptions) brand: 0};
    }

    for (final submission in submissions) {
      final branch = submission.branch;
      if (!result.containsKey(branch)) continue;

      final brandTokens = submission.brands
          .split(',')
          .map((item) => item.trim().toUpperCase())
          .where((item) => item.isNotEmpty)
          .toSet();

      for (final brand in _brandOptions) {
        if (brandTokens.contains(brand)) {
          result[branch]![brand] = (result[branch]![brand] ?? 0) + 1;
        }
      }
    }

    return result;
  }

  Map<String, Map<String, _EncoderMetrics>> _computeEncoderStats(
    List<AdminSubmission> submissions,
  ) {
    final result = <String, Map<String, _EncoderMetrics>>{};

    for (final branch in _branchOptions(includeAll: false)) {
      result[branch] = {
        for (final brand in _brandOptions) brand: const _EncoderMetrics(),
      };
    }

    final now = DateTime.now();

    for (final submission in submissions) {
      final branch = submission.branch;
      if (!result.containsKey(branch)) continue;

      final brandTokens = submission.brands
          .split(',')
          .map((item) => item.trim().toUpperCase())
          .where((item) => item.isNotEmpty)
          .toSet();
      if (brandTokens.isEmpty) continue;

      final signage = _parseQuantity(submission.signageQuantity);
      final awning = _parseQuantity(submission.awningQuantity);
      final flange = _parseQuantity(submission.flangeQuantity);
      final submittedDate = _parseSubmissionDate(submission);
      final isToday = submittedDate != null &&
          submittedDate.year == now.year &&
          submittedDate.month == now.month &&
          submittedDate.day == now.day;

      for (final brand in _brandOptions) {
        if (!brandTokens.contains(brand)) continue;

        final current = result[branch]![brand] ?? const _EncoderMetrics();
        result[branch]![brand] = _EncoderMetrics(
          installedCount: current.installedCount + 1,
          signageTotal: current.signageTotal + signage,
          awningTotal: current.awningTotal + awning,
          flangeTotal: current.flangeTotal + flange,
          dailySignage: current.dailySignage + (isToday ? signage : 0),
          dailyAwning: current.dailyAwning + (isToday ? awning : 0),
          dailyFlange: current.dailyFlange + (isToday ? flange : 0),
        );
      }
    }

    return result;
  }

  Map<String, _EncoderMetrics> _emptyEncoderStats() {
    return {for (final brand in _brandOptions) brand: const _EncoderMetrics()};
  }

  int _parseQuantity(String value) {
    return int.tryParse(value.trim()) ?? 0;
  }

  DateTime? _parseSubmissionDate(AdminSubmission submission) {
    final source = submission.scriptTimestamp.trim().isNotEmpty
        ? submission.scriptTimestamp
        : submission.timestamp;
    final parsed = DateTime.tryParse(source);
    return parsed?.toLocal();
  }

  String _formatTimestamp(String input) {
    final parsed = DateTime.tryParse(input);
    if (parsed == null) return input;
    return _displayDateFormat.format(parsed.toLocal());
  }

  String _formatEntryTimestamp(AdminSubmission entry) {
    if (entry.scriptTimestamp.trim().isNotEmpty) {
      return _formatTimestamp(entry.scriptTimestamp);
    }
    return _formatTimestamp(entry.timestamp);
  }
}

class _EncoderMetrics {
  const _EncoderMetrics({
    this.installedCount = 0,
    this.signageTotal = 0,
    this.awningTotal = 0,
    this.flangeTotal = 0,
    this.dailySignage = 0,
    this.dailyAwning = 0,
    this.dailyFlange = 0,
  });

  final int installedCount;
  final int signageTotal;
  final int awningTotal;
  final int flangeTotal;
  final int dailySignage;
  final int dailyAwning;
  final int dailyFlange;
}
