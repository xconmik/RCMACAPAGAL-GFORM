import 'package:flutter/material.dart';

import '../models/admin_data.dart';
import '../services/admin_service.dart';
import '../services/installer_auth_service.dart';
import 'multi_step_form_screen.dart';

class InstallerHistoryScreen extends StatefulWidget {
  const InstallerHistoryScreen({super.key, required this.profile});

  final InstallerProfile profile;

  @override
  State<InstallerHistoryScreen> createState() => _InstallerHistoryScreenState();
}

class _InstallerHistoryScreenState extends State<InstallerHistoryScreen> {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  String? _error;
  List<AdminSubmission> _submissions = const <AdminSubmission>[];
  String? _selectedOutletCode;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dashboard = await _adminService.fetchDashboardData(
        branch: widget.profile.branch,
        limit: 2000,
      );

      final installerEntries = _mergeInstallerSubmissions(
        dashboard.recentSubmissions,
        widget.profile.installerName,
      );

      if (!mounted) return;
      setState(() {
        _submissions = installerEntries;
        _selectedOutletCode =
            installerEntries.isEmpty ? null : installerEntries.first.outletCode;
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

  List<AdminSubmission> _mergeInstallerSubmissions(
    List<AdminSubmission> submissions,
    String installerName,
  ) {
    final installerKey = installerName.trim().toUpperCase();
    final grouped = <String, _SubmissionGroup>{};

    for (final submission in submissions) {
      if (submission.fullName.trim().toUpperCase() != installerKey) continue;
      if (submission.branch.trim() != widget.profile.branch.trim()) continue;

      final timestampKey = submission.scriptTimestamp.trim().isNotEmpty
          ? submission.scriptTimestamp.trim()
          : submission.timestamp.trim();
      final groupKey =
          '${submission.branch}|${submission.outletCode}|${submission.fullName}|$timestampKey';

      final group = grouped.putIfAbsent(
        groupKey,
        () => _SubmissionGroup(base: submission),
      );
      group.addBrands(submission.brands);
    }

    final merged = grouped.values.map((group) => group.toSubmission()).toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(
              a.scriptTimestamp.trim().isNotEmpty
                  ? a.scriptTimestamp
                  : a.timestamp,
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(
              b.scriptTimestamp.trim().isNotEmpty
                  ? b.scriptTimestamp
                  : b.timestamp,
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    final latestByOutlet = <String, AdminSubmission>{};
    for (final submission in merged) {
      final outletCode = submission.outletCode.trim();
      if (outletCode.isEmpty) continue;
      latestByOutlet.putIfAbsent(outletCode, () => submission);
    }

    return latestByOutlet.values.toList()
      ..sort((a, b) {
        final aDate = DateTime.tryParse(
              a.scriptTimestamp.trim().isNotEmpty
                  ? a.scriptTimestamp
                  : a.timestamp,
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse(
              b.scriptTimestamp.trim().isNotEmpty
                  ? b.scriptTimestamp
                  : b.timestamp,
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
  }

  @override
  Widget build(BuildContext context) {
    final current = _submissions.where(
      (submission) => submission.outletCode == _selectedOutletCode,
    );
    final selectedSubmission = current.isEmpty ? null : current.first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Installer History'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildBody(selectedSubmission),
        ),
      ),
    );
  }

  Widget _buildBody(AdminSubmission? selectedSubmission) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(child: Text('Unable to load history. $_error'));
    }

    if (_submissions.isEmpty) {
      return const Center(
        child: Text('No submission history found for this installer yet.'),
      );
    }

    return ListView(
      children: [
        Text(
          widget.profile.installerName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          widget.profile.branch,
          style: const TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedOutletCode,
          decoration: const InputDecoration(
            labelText: 'Outlet Code',
            border: OutlineInputBorder(),
          ),
          items: _submissions
              .map(
                (submission) => DropdownMenuItem<String>(
                  value: submission.outletCode,
                  child: Text(submission.outletCode),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedOutletCode = value;
            });
          },
        ),
        const SizedBox(height: 16),
        if (selectedSubmission != null)
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedSubmission.outletCode,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Last submitted: ${_formatTimestamp(selectedSubmission)}'),
                  Text(
                    'Brand: ${selectedSubmission.brands.isEmpty ? '-' : selectedSubmission.brands}',
                  ),
                  Text(
                    'Store Name: ${selectedSubmission.signageName.isEmpty ? '-' : selectedSubmission.signageName}',
                  ),
                  Text(
                    'Owner: ${selectedSubmission.storeOwnerName.isEmpty ? '-' : selectedSubmission.storeOwnerName}',
                  ),
                  Text(
                    'Quantities - Signage: ${selectedSubmission.signageQuantity}, Awnings: ${selectedSubmission.awningQuantity}, Flange: ${selectedSubmission.flangeQuantity}',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      final updated = await Navigator.of(context).push<bool>(
                        MaterialPageRoute<bool>(
                          builder: (_) => MultiStepFormScreen(
                            initialSubmission: selectedSubmission,
                          ),
                        ),
                      );

                      if (updated == true) {
                        await _loadHistory();
                      }
                    },
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Edit & Reupload'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatTimestamp(AdminSubmission submission) {
    final raw = submission.scriptTimestamp.trim().isNotEmpty
        ? submission.scriptTimestamp
        : submission.timestamp;
    final parsed = DateTime.tryParse(raw)?.toLocal();
    if (parsed == null) return raw;

    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatFullDate(parsed)} ${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(parsed))}';
  }
}

class _SubmissionGroup {
  _SubmissionGroup({required this.base});

  final AdminSubmission base;
  final Set<String> _brands = <String>{};

  void addBrands(String brands) {
    _brands.addAll(
      brands
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    );
  }

  AdminSubmission toSubmission() {
    final mergedBrands =
        _brands.isEmpty ? base.brands : (_brands.toList()..sort()).join(', ');

    return AdminSubmission(
      entryId: base.entryId,
      spreadsheetId: base.spreadsheetId,
      rowNumber: base.rowNumber,
      timestamp: base.timestamp,
      scriptTimestamp: base.scriptTimestamp,
      branch: base.branch,
      fullName: base.fullName,
      outletCode: base.outletCode,
      brands: mergedBrands,
      signageName: base.signageName,
      storeOwnerName: base.storeOwnerName,
      signageQuantity: base.signageQuantity,
      awningQuantity: base.awningQuantity,
      flangeQuantity: base.flangeQuantity,
      beforeImageDriveUrl: base.beforeImageDriveUrl,
      afterImageDriveUrl: base.afterImageDriveUrl,
      completionImageDriveUrl: base.completionImageDriveUrl,
      refusalImageDriveUrl: base.refusalImageDriveUrl,
    );
  }
}
