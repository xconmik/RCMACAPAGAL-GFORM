import 'captured_image_data.dart';

class InstallationFormData {
  String? branch;
  String? fullName;
  String? outletCode;
  String? signageName;
  String? storeOwnerName;
  String? purok;
  String? barangay;
  String? municipality;
  String? completeAddress;
  List<String> brands = [];
  String? signageQuantity;
  String? signageQuantityOther;
  String? awningQuantity;
  String? awningQuantityOther;
  String? flangeQuantity;
  String? flangeQuantityOther;
  final List<CapturedImageData> beforeImages = [];
  final List<CapturedImageData> afterImages = [];
  final List<CapturedImageData> completionImages = [];
  final List<CapturedImageData> refusalImages = [];

  CapturedImageData? get beforeImage =>
      beforeImages.isEmpty ? null : beforeImages.last;
  set beforeImage(CapturedImageData? value) {
    beforeImages
      ..clear()
      ..addAll(value == null ? const [] : [value]);
  }

  CapturedImageData? get afterImage =>
      afterImages.isEmpty ? null : afterImages.last;
  set afterImage(CapturedImageData? value) {
    afterImages
      ..clear()
      ..addAll(value == null ? const [] : [value]);
  }

  CapturedImageData? get completionImage =>
      completionImages.isEmpty ? null : completionImages.last;
  set completionImage(CapturedImageData? value) {
    completionImages
      ..clear()
      ..addAll(value == null ? const [] : [value]);
  }

  CapturedImageData? get refusalImage =>
      refusalImages.isEmpty ? null : refusalImages.last;
  set refusalImage(CapturedImageData? value) {
    refusalImages
      ..clear()
      ..addAll(value == null ? const [] : [value]);
  }

  Map<String, dynamic> toJson() {
    return {
      'branch': branch,
      'fullName': fullName,
      'outletCode': outletCode,
      'signageName': signageName,
      'storeOwnerName': storeOwnerName,
      'purok': purok,
      'barangay': barangay,
      'municipality': municipality,
      'completeAddress': completeAddress,
      'brands': brands,
      'signageQuantity': signageQuantity,
      'signageQuantityOther': signageQuantityOther,
      'awningQuantity': awningQuantity,
      'awningQuantityOther': awningQuantityOther,
      'flangeQuantity': flangeQuantity,
      'flangeQuantityOther': flangeQuantityOther,
      'beforeImage': beforeImage?.toJson(),
      'afterImage': afterImage?.toJson(),
      'completionImage': completionImage?.toJson(),
      'refusalImage': refusalImage?.toJson(),
      'beforeImages': beforeImages.map((item) => item.toJson()).toList(),
      'afterImages': afterImages.map((item) => item.toJson()).toList(),
      'completionImages':
          completionImages.map((item) => item.toJson()).toList(),
      'refusalImages': refusalImages.map((item) => item.toJson()).toList(),
    };
  }
}
