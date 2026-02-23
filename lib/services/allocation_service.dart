import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AllocationService {
  static const _key = 'admin_branch_allocations_v2';
  static const List<String> _defaultTypes = ['signage', 'awning', 'flange'];

  Future<Map<String, Map<String, Map<String, int>>>> loadAllocations({
    required List<String> branches,
    required List<String> brands,
    List<String> types = _defaultTypes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getString(_key) ?? prefs.getString('admin_branch_allocations_v1');

    final result = <String, Map<String, Map<String, int>>>{};

    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        for (final branch in decoded.entries) {
          if (branch.value is Map<String, dynamic>) {
            final typeMap = <String, Map<String, int>>{};
            final values = branch.value as Map<String, dynamic>;

            final isTypedStructure = values.values.any((value) => value is Map);

            if (isTypedStructure) {
              for (final type in types) {
                final rawBrandMap = values[type];
                final parsedBrandMap = <String, int>{};

                if (rawBrandMap is Map<String, dynamic>) {
                  for (final brand in brands) {
                    parsedBrandMap[brand] =
                        int.tryParse('${rawBrandMap[brand] ?? 0}') ?? 0;
                  }
                } else {
                  for (final brand in brands) {
                    parsedBrandMap[brand] = 0;
                  }
                }

                typeMap[type] = parsedBrandMap;
              }
            } else {
              final legacyBrandMap = <String, int>{};
              for (final brand in brands) {
                legacyBrandMap[brand] =
                    int.tryParse('${values[brand] ?? 0}') ?? 0;
              }

              for (final type in types) {
                typeMap[type] = {
                  for (final brand in brands) brand: legacyBrandMap[brand] ?? 0
                };
              }
            }

            result[branch.key] = typeMap;
          }
        }
      }
    }

    for (final branch in branches) {
      result.putIfAbsent(branch, () => <String, Map<String, int>>{});
      for (final type in types) {
        result[branch]!.putIfAbsent(type, () => <String, int>{});
        for (final brand in brands) {
          result[branch]![type]!.putIfAbsent(brand, () => 0);
        }
      }
    }

    return result;
  }

  Future<void> saveAllocations(
    Map<String, Map<String, Map<String, int>>> allocations,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(allocations));
  }
}
