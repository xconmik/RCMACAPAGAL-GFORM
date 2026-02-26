class BranchSummary {
  const BranchSummary({
    required this.branch,
    required this.spreadsheetId,
    required this.totalRows,
  });

  final String branch;
  final String spreadsheetId;
  final int totalRows;

  factory BranchSummary.fromJson(Map<String, dynamic> json) {
    return BranchSummary(
      branch: (json['branch'] ?? '').toString(),
      spreadsheetId: (json['spreadsheetId'] ?? '').toString(),
      totalRows: int.tryParse((json['totalRows'] ?? 0).toString()) ?? 0,
    );
  }
}

class AdminSubmission {
  const AdminSubmission({
    required this.entryId,
    required this.spreadsheetId,
    required this.rowNumber,
    required this.timestamp,
    required this.scriptTimestamp,
    required this.branch,
    required this.fullName,
    required this.outletCode,
    required this.brands,
    required this.signageName,
    required this.storeOwnerName,
    required this.signageQuantity,
    required this.awningQuantity,
    required this.flangeQuantity,
    required this.beforeImageDriveUrl,
    required this.afterImageDriveUrl,
    required this.completionImageDriveUrl,
  });

  final String entryId;
  final String spreadsheetId;
  final int? rowNumber;
  final String timestamp;
  final String scriptTimestamp;
  final String branch;
  final String fullName;
  final String outletCode;
  final String brands;
  final String signageName;
  final String storeOwnerName;
  final String signageQuantity;
  final String awningQuantity;
  final String flangeQuantity;
  final String beforeImageDriveUrl;
  final String afterImageDriveUrl;
  final String completionImageDriveUrl;

  factory AdminSubmission.fromJson(Map<String, dynamic> json) {
    return AdminSubmission(
      entryId: (json['entryId'] ?? '').toString(),
      spreadsheetId: (json['spreadsheetId'] ?? '').toString(),
      rowNumber: int.tryParse((json['rowNumber'] ?? '').toString()),
      timestamp: (json['timestamp'] ?? '').toString(),
      scriptTimestamp:
          (json['scriptTimestamp'] ?? json['timestamp'] ?? '').toString(),
      branch: (json['branch'] ?? '').toString(),
      fullName: (json['fullName'] ?? '').toString(),
      outletCode: (json['outletCode'] ?? '').toString(),
      brands: (json['brands'] ?? '').toString(),
      signageName: (json['signageName'] ?? '').toString(),
      storeOwnerName: (json['storeOwnerName'] ?? '').toString(),
      signageQuantity: (json['signageQuantity'] ?? '').toString(),
      awningQuantity: (json['awningQuantity'] ?? '').toString(),
      flangeQuantity: (json['flangeQuantity'] ?? '').toString(),
      beforeImageDriveUrl: (json['beforeImageDriveUrl'] ?? '').toString(),
      afterImageDriveUrl: (json['afterImageDriveUrl'] ?? '').toString(),
      completionImageDriveUrl:
          (json['completionImageDriveUrl'] ?? '').toString(),
    );
  }
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.selectedBranch,
    required this.totalSubmissions,
    required this.scriptTimestamp,
    required this.branches,
    required this.recentSubmissions,
    required this.recentInstallerLocations,
  });

  final String selectedBranch;
  final int totalSubmissions;
  final String scriptTimestamp;
  final List<BranchSummary> branches;
  final List<AdminSubmission> recentSubmissions;
  final List<AdminTrackingLocation> recentInstallerLocations;

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    final branchesJson = (json['branches'] as List?) ?? [];
    final recentJson = (json['recentSubmissions'] as List?) ?? [];
    final trackingJson = (json['recentInstallerLocations'] as List?) ?? [];

    return AdminDashboardData(
      selectedBranch: (json['selectedBranch'] ?? 'ALL').toString(),
      totalSubmissions:
          int.tryParse((json['totalSubmissions'] ?? 0).toString()) ?? 0,
      scriptTimestamp: (json['scriptTimestamp'] ?? '').toString(),
      branches: branchesJson
          .whereType<Map>()
          .map((item) => BranchSummary.fromJson(item.cast<String, dynamic>()))
          .toList(),
      recentSubmissions: recentJson
          .whereType<Map>()
          .map((item) => AdminSubmission.fromJson(item.cast<String, dynamic>()))
          .toList(),
      recentInstallerLocations: trackingJson
          .whereType<Map>()
          .map(
            (item) => AdminTrackingLocation.fromJson(item.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

class AdminTrackingLocation {
  const AdminTrackingLocation({
    required this.branch,
    required this.installerName,
    required this.latitude,
    required this.longitude,
    required this.trackedAt,
    required this.scriptTimestamp,
    required this.sessionId,
  });

  final String branch;
  final String installerName;
  final double latitude;
  final double longitude;
  final String trackedAt;
  final String scriptTimestamp;
  final String sessionId;

  factory AdminTrackingLocation.fromJson(Map<String, dynamic> json) {
    return AdminTrackingLocation(
      branch: (json['branch'] ?? '').toString(),
      installerName: (json['installerName'] ?? '').toString(),
      latitude: double.tryParse((json['latitude'] ?? '').toString()) ?? 0,
      longitude: double.tryParse((json['longitude'] ?? '').toString()) ?? 0,
      trackedAt: (json['trackedAt'] ?? '').toString(),
      scriptTimestamp: (json['scriptTimestamp'] ?? '').toString(),
      sessionId: (json['sessionId'] ?? '').toString(),
    );
  }
}
