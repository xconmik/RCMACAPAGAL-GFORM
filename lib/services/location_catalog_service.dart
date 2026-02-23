import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class LocationCatalogService {
  static const String _assetPath = 'assets/location_catalog.json';

  Future<LocationCatalog> loadCatalog() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid location catalog format.');
    }

    final branchesJson = (decoded['branches'] as List?) ?? const [];

    final branches = <String>[];
    final branchMunicipalities = <String, List<String>>{};
    final branchMunicipalityBarangays =
      <String, Map<String, List<String>>>{};

    for (final branchItem in branchesJson) {
      if (branchItem is! Map) continue;

      final branchMap = branchItem.cast<String, dynamic>();
      final branchName = (branchMap['name'] ?? '').toString().trim();
      if (branchName.isEmpty) continue;

      branches.add(branchName);

      final municipalitiesJson =
          (branchMap['municipalities'] as List?) ?? const [];
      final municipalityNames = <String>[];
        final municipalityBarangays = <String, List<String>>{};

      for (final municipalityItem in municipalitiesJson) {
        if (municipalityItem is! Map) continue;

        final municipalityMap = municipalityItem.cast<String, dynamic>();
        final municipalityName =
            (municipalityMap['name'] ?? '').toString().trim();
        if (municipalityName.isEmpty) continue;

        municipalityNames.add(municipalityName);

        final barangays = ((municipalityMap['barangays'] as List?) ?? const [])
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();

        municipalityBarangays[municipalityName] = barangays;
      }

      branchMunicipalities[branchName] = municipalityNames;
      branchMunicipalityBarangays[branchName] = municipalityBarangays;
    }

    return LocationCatalog(
      branches: branches,
      branchMunicipalities: branchMunicipalities,
      branchMunicipalityBarangays: branchMunicipalityBarangays,
    );
  }
}

class LocationCatalog {
  const LocationCatalog({
    required this.branches,
    required this.branchMunicipalities,
    required this.branchMunicipalityBarangays,
  });

  final List<String> branches;
  final Map<String, List<String>> branchMunicipalities;
  final Map<String, Map<String, List<String>>> branchMunicipalityBarangays;
}
