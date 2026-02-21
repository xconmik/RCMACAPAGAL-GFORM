import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AllocationService {
  static const _key = 'admin_branch_allocations_v1';

  Future<Map<String, Map<String, int>>> loadAllocations({
    required List<String> branches,
    required List<String> brands,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);

    final result = <String, Map<String, int>>{};

    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        for (final branch in decoded.entries) {
          if (branch.value is Map<String, dynamic>) {
            final brandMap = <String, int>{};
            final values = branch.value as Map<String, dynamic>;
            for (final brand in values.entries) {
              brandMap[brand.key] = int.tryParse('${brand.value}') ?? 0;
            }
            result[branch.key] = brandMap;
          }
        }
      }
    }

    for (final branch in branches) {
      result.putIfAbsent(branch, () => <String, int>{});
      for (final brand in brands) {
        result[branch]!.putIfAbsent(brand, () => 0);
      }
    }

    return result;
  }

  Future<void> saveAllocations(Map<String, Map<String, int>> allocations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(allocations));
  }
}
