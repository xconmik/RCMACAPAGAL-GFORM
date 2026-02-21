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
  CapturedImageData? beforeImage;
  CapturedImageData? afterImage;
  CapturedImageData? completionImage;

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
      'submittedAt': DateTime.now().toIso8601String(),
    };
  }
}
