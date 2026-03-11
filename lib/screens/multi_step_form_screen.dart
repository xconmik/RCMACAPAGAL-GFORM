import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/admin_data.dart';
import '../models/captured_image_data.dart';
import '../models/installation_form_data.dart';
import '../services/installer_auth_service.dart';
import '../services/image_capture_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_catalog_service.dart';
import '../services/upload_service.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/step_card.dart';

class MultiStepFormScreen extends StatefulWidget {
  const MultiStepFormScreen({
    super.key,
    this.initialSubmission,
    this.initialInstallerProfile,
  });

  final AdminSubmission? initialSubmission;
  final InstallerProfile? initialInstallerProfile;

  @override
  State<MultiStepFormScreen> createState() => _MultiStepFormScreenState();
}

class _MultiStepFormScreenState extends State<MultiStepFormScreen>
    with WidgetsBindingObserver {
  static const int _maxImagesPerSection = 3;

  static const List<String> _brands = [
    'CAMEL',
    'WINSTON',
    'MIGHTY',
    'MIGHTY RED',
  ];

  static const List<String> _quantityOptions = [
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    'REFUSED',
    'OTHERS',
  ];

  final PageController _pageController = PageController();
  final InstallationFormData _formData = InstallationFormData();
  final ImageCaptureService _imageCaptureService = ImageCaptureService();
  final UploadService _uploadService = UploadService();
  final LocalStorageService _localStorageService = LocalStorageService();
  final LocationCatalogService _locationCatalogService =
      LocationCatalogService();

  final TextEditingController _outletCodeController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _signageNameController = TextEditingController();
  final TextEditingController _storeOwnerController = TextEditingController();
  final TextEditingController _purokController = TextEditingController();
  final TextEditingController _municipalityController = TextEditingController();
  final TextEditingController _barangayController = TextEditingController();
  final TextEditingController _signageOtherController = TextEditingController();
  final TextEditingController _awningOtherController = TextEditingController();
  final TextEditingController _flangeOtherController = TextEditingController();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _isUploadingBefore = false;
  bool _isUploadingAfter = false;
  bool _isUploadingCompletion = false;
  bool _isUploadingRefusal = false;
  bool _isBootstrappingForm = true;
  bool _isLocationCatalogLoading = true;
  String? _locationCatalogError;
  String? _selectedMunicipality;
  String? _selectedBarangay;

  List<String> _branches = const <String>[];
  Map<String, List<String>> _branchMunicipalities =
      const <String, List<String>>{};
  Map<String, Map<String, List<String>>> _branchMunicipalityBarangays =
      const <String, Map<String, List<String>>>{};

  bool get _isEditMode => widget.initialSubmission != null;
  InstallerProfile? get _prefilledInstallerProfile =>
      _isEditMode ? null : widget.initialInstallerProfile;
  bool get _hasLockedInstallerProfile =>
      _prefilledInstallerProfile != null &&
      _prefilledInstallerProfile!.isGuest != true;
  bool get _requiresRefusalForm {
    return _formData.signageQuantity == 'REFUSED' ||
        _formData.awningQuantity == 'REFUSED' ||
        _formData.flangeQuantity == 'REFUSED';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_isEditMode) {
      _restoreSubmissionForEditing(widget.initialSubmission!);
    } else if (_prefilledInstallerProfile != null) {
      _applyInstallerProfileDefaults(_prefilledInstallerProfile!);
    }
    _initializeFormState();
  }

  Future<void> _initializeFormState() async {
    try {
      await _loadLocationCatalog();
      if (!_isEditMode) {
        await _restoreDraftIfAvailable();
      }
    } finally {
      if (!mounted) return;
      setState(() {
        _isBootstrappingForm = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveDraftSnapshot();
    }
  }

  Future<void> _loadLocationCatalog() async {
    setState(() {
      _isLocationCatalogLoading = true;
      _locationCatalogError = null;
    });

    try {
      final catalog = await _locationCatalogService.loadCatalog();

      if (!mounted) return;
      setState(() {
        _branches = catalog.branches;
        _branchMunicipalities = catalog.branchMunicipalities;
        _branchMunicipalityBarangays = catalog.branchMunicipalityBarangays;
        _isLocationCatalogLoading = false;

        if (_formData.branch != null && !_branches.contains(_formData.branch)) {
          _formData.branch = null;
          _selectedMunicipality = null;
          _selectedBarangay = null;
          _municipalityController.clear();
          _barangayController.clear();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocationCatalogLoading = false;
        _locationCatalogError = 'Failed to load location catalog. $e';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _fullNameController.dispose();
    _outletCodeController.dispose();
    _signageNameController.dispose();
    _storeOwnerController.dispose();
    _purokController.dispose();
    _municipalityController.dispose();
    _barangayController.dispose();
    _signageOtherController.dispose();
    _awningOtherController.dispose();
    _flangeOtherController.dispose();
    super.dispose();
  }

  void _syncControllersToFormData() {
    _formData.fullName = _fullNameController.text.trim().isEmpty
        ? null
        : _fullNameController.text.trim();
    _formData.outletCode = _outletCodeController.text.trim().isEmpty
        ? null
        : _outletCodeController.text.trim();
    _formData.signageName = _signageNameController.text.trim().isEmpty
        ? null
        : _signageNameController.text.trim();
    _formData.storeOwnerName = _storeOwnerController.text.trim().isEmpty
        ? null
        : _storeOwnerController.text.trim();

    _formData.purok = _purokController.text.trim().isEmpty
        ? null
        : _purokController.text.trim();
    _formData.municipality = _selectedMunicipality;
    _formData.barangay = _selectedBarangay;

    if ((_formData.purok ?? '').isNotEmpty &&
        (_formData.barangay ?? '').isNotEmpty &&
        (_formData.municipality ?? '').isNotEmpty) {
      _formData.completeAddress =
          'Purok ${_formData.purok}, ${_formData.barangay}, ${_formData.municipality}';
    }
  }

  Map<String, dynamic> _buildDraftPayload() {
    _syncControllersToFormData();

    final payload = _formData.toJson();
    payload['draftCurrentStep'] = _currentStep;
    payload['draftSelectedMunicipality'] = _selectedMunicipality;
    payload['draftSelectedBarangay'] = _selectedBarangay;
    return payload;
  }

  Future<void> _saveDraftSnapshot() async {
    await _localStorageService.saveDraft(_buildDraftPayload());
  }

  List<CapturedImageData> _capturedImagesFromDraft(
    dynamic raw, {
    dynamic legacyRaw,
  }) {
    final results = <CapturedImageData>[];

    if (raw is List) {
      for (final item in raw.whereType<Map>()) {
        final image = CapturedImageData.fromJson(item.cast<String, dynamic>());
        if (image.filePath.trim().isNotEmpty) {
          results.add(image);
        }
      }
    } else if (raw is Map) {
      final image = CapturedImageData.fromJson(raw.cast<String, dynamic>());
      if (image.filePath.trim().isNotEmpty) {
        results.add(image);
      }
    }

    if (results.isEmpty && legacyRaw is Map) {
      final image =
          CapturedImageData.fromJson(legacyRaw.cast<String, dynamic>());
      if (image.filePath.trim().isNotEmpty) {
        results.add(image);
      }
    }

    return results.take(_maxImagesPerSection).toList();
  }

  Future<void> _restoreDraftIfAvailable() async {
    final draft = await _localStorageService.loadDraft();
    if (!mounted || draft == null || draft.isEmpty) return;

    final brandsRaw = draft['brands'];
    final restoredBrands = brandsRaw is List
        ? brandsRaw
            .map((item) => item.toString().trim().toUpperCase())
            .where((item) => item.isNotEmpty)
            .toList()
        : <String>[];

    const maxStep = 10;
    final restoredStep = (draft['draftCurrentStep'] as num?)?.toInt() ?? 0;
    final safeStep = restoredStep.clamp(0, maxStep);

    setState(() {
      _formData.branch = (draft['branch'] ?? '').toString().trim().isEmpty
          ? null
          : draft['branch'].toString();
      _formData.fullName = (draft['fullName'] ?? '').toString().trim().isEmpty
          ? null
          : draft['fullName'].toString();
      _formData.outletCode =
          (draft['outletCode'] ?? '').toString().trim().isEmpty
              ? null
              : draft['outletCode'].toString();
      _formData.signageName =
          (draft['signageName'] ?? '').toString().trim().isEmpty
              ? null
              : draft['signageName'].toString();
      _formData.storeOwnerName =
          (draft['storeOwnerName'] ?? '').toString().trim().isEmpty
              ? null
              : draft['storeOwnerName'].toString();
      _formData.purok = (draft['purok'] ?? '').toString().trim().isEmpty
          ? null
          : draft['purok'].toString();
      _formData.barangay = (draft['barangay'] ?? '').toString().trim().isEmpty
          ? null
          : draft['barangay'].toString();
      _formData.municipality =
          (draft['municipality'] ?? '').toString().trim().isEmpty
              ? null
              : draft['municipality'].toString();
      _formData.completeAddress =
          (draft['completeAddress'] ?? '').toString().trim().isEmpty
              ? null
              : draft['completeAddress'].toString();
      _formData.signageQuantity =
          (draft['signageQuantity'] ?? '').toString().trim().isEmpty
              ? null
              : draft['signageQuantity'].toString();
      _formData.signageQuantityOther =
          (draft['signageQuantityOther'] ?? '').toString().trim().isEmpty
              ? null
              : draft['signageQuantityOther'].toString();
      _formData.awningQuantity =
          (draft['awningQuantity'] ?? '').toString().trim().isEmpty
              ? null
              : draft['awningQuantity'].toString();
      _formData.awningQuantityOther =
          (draft['awningQuantityOther'] ?? '').toString().trim().isEmpty
              ? null
              : draft['awningQuantityOther'].toString();
      _formData.flangeQuantity =
          (draft['flangeQuantity'] ?? '').toString().trim().isEmpty
              ? null
              : draft['flangeQuantity'].toString();
      _formData.flangeQuantityOther =
          (draft['flangeQuantityOther'] ?? '').toString().trim().isEmpty
              ? null
              : draft['flangeQuantityOther'].toString();
      _formData.beforeImages
        ..clear()
        ..addAll(_capturedImagesFromDraft(
          draft['beforeImages'],
          legacyRaw: draft['beforeImage'],
        ));
      _formData.afterImages
        ..clear()
        ..addAll(_capturedImagesFromDraft(
          draft['afterImages'],
          legacyRaw: draft['afterImage'],
        ));
      _formData.completionImages
        ..clear()
        ..addAll(_capturedImagesFromDraft(
          draft['completionImages'],
          legacyRaw: draft['completionImage'],
        ));
      _formData.refusalImages
        ..clear()
        ..addAll(_capturedImagesFromDraft(
          draft['refusalImages'],
          legacyRaw: draft['refusalImage'],
        ));

      _formData.brands
        ..clear()
        ..addAll(restoredBrands);

      _selectedMunicipality =
          (draft['draftSelectedMunicipality'] ?? draft['municipality'])
                  .toString()
                  .trim()
                  .isEmpty
              ? null
              : (draft['draftSelectedMunicipality'] ?? draft['municipality'])
                  .toString();
      _selectedBarangay = (draft['draftSelectedBarangay'] ?? draft['barangay'])
              .toString()
              .trim()
              .isEmpty
          ? null
          : (draft['draftSelectedBarangay'] ?? draft['barangay']).toString();

      _currentStep = safeStep;
    });

    _fullNameController.text = _formData.fullName ?? '';
    _outletCodeController.text = _formData.outletCode ?? '';
    _signageNameController.text = _formData.signageName ?? '';
    _storeOwnerController.text = _formData.storeOwnerName ?? '';
    _purokController.text = _formData.purok ?? '';
    _municipalityController.text = _selectedMunicipality ?? '';
    _barangayController.text = _selectedBarangay ?? '';
    _signageOtherController.text = _formData.signageQuantityOther ?? '';
    _awningOtherController.text = _formData.awningQuantityOther ?? '';
    _flangeOtherController.text = _formData.flangeQuantityOther ?? '';

    if (_prefilledInstallerProfile != null) {
      _applyInstallerProfileDefaults(_prefilledInstallerProfile!);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _pageController.jumpToPage(_currentStep);
      _showError('Draft restored. You are back on your last step.');
    });
  }

  void _restoreSubmissionForEditing(AdminSubmission submission) {
    final restoredBrands = submission.brands
        .split(',')
        .map((item) => item.trim().toUpperCase())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();

    final signageSelection =
        _normalizeQuantitySelection(submission.signageQuantity);
    final awningSelection =
        _normalizeQuantitySelection(submission.awningQuantity);
    final flangeSelection =
        _normalizeQuantitySelection(submission.flangeQuantity);

    _formData.branch =
        submission.branch.trim().isEmpty ? null : submission.branch;
    _formData.fullName =
        submission.fullName.trim().isEmpty ? null : submission.fullName;
    _formData.outletCode =
        submission.outletCode.trim().isEmpty ? null : submission.outletCode;
    _formData.signageName =
        submission.signageName.trim().isEmpty ? null : submission.signageName;
    _formData.storeOwnerName = submission.storeOwnerName.trim().isEmpty
        ? null
        : submission.storeOwnerName;
    _formData.completeAddress = null;
    _formData.purok = null;
    _formData.barangay = null;
    _formData.municipality = null;
    _formData.beforeImages.clear();
    _formData.afterImages.clear();
    _formData.completionImages.clear();
    _formData.refusalImages.clear();
    _formData.signageQuantity = signageSelection.selection;
    _formData.signageQuantityOther = signageSelection.otherValue;
    _formData.awningQuantity = awningSelection.selection;
    _formData.awningQuantityOther = awningSelection.otherValue;
    _formData.flangeQuantity = flangeSelection.selection;
    _formData.flangeQuantityOther = flangeSelection.otherValue;
    _formData.brands
      ..clear()
      ..addAll(restoredBrands);

    _fullNameController.text = _formData.fullName ?? '';
    _outletCodeController.text = _formData.outletCode ?? '';
    _signageNameController.text = _formData.signageName ?? '';
    _storeOwnerController.text = _formData.storeOwnerName ?? '';
    _purokController.clear();
    _municipalityController.clear();
    _barangayController.clear();
    _signageOtherController.text = _formData.signageQuantityOther ?? '';
    _awningOtherController.text = _formData.awningQuantityOther ?? '';
    _flangeOtherController.text = _formData.flangeQuantityOther ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showError(
        'Editing previous submission. Review details and reupload all photos before saving.',
      );
    });
  }

  _QuantitySelection _normalizeQuantitySelection(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const _QuantitySelection(selection: null, otherValue: null);
    }

    final upper = trimmed.toUpperCase();
    if (_quantityOptions.contains(upper)) {
      return _QuantitySelection(selection: upper, otherValue: null);
    }

    return _QuantitySelection(selection: 'OTHERS', otherValue: trimmed);
  }

  void _applyInstallerProfileDefaults(InstallerProfile profile) {
    if (profile.branch.trim().isNotEmpty) {
      _formData.branch = profile.branch.trim();
    }

    if (profile.installerName.trim().isNotEmpty) {
      _formData.fullName = profile.installerName.trim();
      _fullNameController.text = profile.installerName.trim();
    }
  }

  String? _resolveTypedSelection(
    TextEditingController controller,
    List<String> options, {
    String? currentValue,
  }) {
    final typed = controller.text.trim();
    if (typed.isEmpty) return null;

    if (currentValue != null &&
        currentValue.trim().toLowerCase() == typed.toLowerCase() &&
        options.contains(currentValue)) {
      return currentValue;
    }

    for (final option in options) {
      if (option.toLowerCase() == typed.toLowerCase()) {
        return option;
      }
    }

    return null;
  }

  Future<void> _goNext() async {
    if (_isBootstrappingForm) {
      _showError('Please wait while the form finishes loading.');
      return;
    }

    if (!_validateCurrentStep()) return;

    if (_currentStep < 10) {
      setState(() {
        _currentStep += 1;
      });
      await _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _goBack() async {
    if (_isSubmitting ||
        _isUploadingBefore ||
        _isUploadingAfter ||
        _isUploadingCompletion ||
        _isUploadingRefusal) {
      _showError('Please wait for the current upload to finish.');
      return;
    }

    if (_currentStep > 0) {
      await _saveDraftSnapshot();
      if (!mounted) return;

      setState(() {
        _currentStep -= 1;
      });

      await _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
      return;
    }

    await _saveDraftSnapshot();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0:
        if (_isLocationCatalogLoading) {
          _showError('Location data is still loading. Please wait.');
          return false;
        }

        if (_locationCatalogError != null) {
          _showError('Location data failed to load. Tap RETRY first.');
          return false;
        }

        if (_formData.branch == null || _formData.branch!.isEmpty) {
          _showError('Please select a branch.');
          return false;
        }
        return true;
      case 1:
        if (_fullNameController.text.trim().isEmpty) {
          _showError('Installer name is required.');
          return false;
        }
        _formData.fullName = _fullNameController.text.trim();
        return true;
      case 2:
        if (_outletCodeController.text.trim().isEmpty) {
          _showError('Outlet code is required.');
          return false;
        }
        _formData.outletCode = _outletCodeController.text.trim();
        return true;
      case 3:
        if (_signageNameController.text.trim().isEmpty) {
          _showError('Store name is required.');
          return false;
        }
        _formData.signageName = _signageNameController.text.trim();
        return true;
      case 4:
        if (_storeOwnerController.text.trim().isEmpty) {
          _showError('Store owner name is required.');
          return false;
        }
        _formData.storeOwnerName = _storeOwnerController.text.trim();
        return true;
      case 5:
        final municipalities = _municipalityOptions();
        final resolvedMunicipality = _resolveTypedSelection(
          _municipalityController,
          municipalities,
          currentValue: _selectedMunicipality,
        );

        if (resolvedMunicipality == null || resolvedMunicipality.isEmpty) {
          _showError('Please select a municipality.');
          return false;
        }

        final barangays = _barangayOptions(municipality: resolvedMunicipality);
        final resolvedBarangay = _resolveTypedSelection(
          _barangayController,
          barangays,
          currentValue: _selectedBarangay,
        );

        if (resolvedBarangay == null || resolvedBarangay.isEmpty) {
          _showError('Please select a barangay.');
          return false;
        }

        if (_purokController.text.trim().isEmpty) {
          _showError('Purok is required.');
          return false;
        }

        _formData.purok = _purokController.text.trim();
        _selectedMunicipality = resolvedMunicipality;
        _selectedBarangay = resolvedBarangay;
        _municipalityController.text = resolvedMunicipality;
        _barangayController.text = resolvedBarangay;
        _formData.barangay = resolvedBarangay;
        _formData.municipality = resolvedMunicipality;
        _formData.completeAddress =
            'Purok ${_formData.purok}, ${_formData.barangay}, ${_formData.municipality}';
        return true;
      case 6:
        if (_formData.brands.isEmpty) {
          _showError('Please select at least one brand.');
          return false;
        }
        return true;
      case 7:
        if (_formData.signageQuantity == null ||
            _formData.signageQuantity!.isEmpty) {
          _showError('Please choose signage quantity.');
          return false;
        }

        if (_formData.signageQuantity == 'OTHERS' &&
            _signageOtherController.text.trim().isEmpty) {
          _showError('Please specify signage quantity for OTHERS.');
          return false;
        }

        _formData.signageQuantityOther = _formData.signageQuantity == 'OTHERS'
            ? _signageOtherController.text.trim()
            : null;
        return true;
      case 8:
        if (_formData.awningQuantity == null ||
            _formData.awningQuantity!.isEmpty) {
          _showError('Please choose awning quantity.');
          return false;
        }

        if (_formData.awningQuantity == 'OTHERS' &&
            _awningOtherController.text.trim().isEmpty) {
          _showError('Please specify awning quantity for OTHERS.');
          return false;
        }

        _formData.awningQuantityOther = _formData.awningQuantity == 'OTHERS'
            ? _awningOtherController.text.trim()
            : null;
        return true;
      case 9:
        if (_formData.flangeQuantity == null ||
            _formData.flangeQuantity!.isEmpty) {
          _showError('Please choose flange quantity.');
          return false;
        }

        if (_formData.flangeQuantity == 'OTHERS' &&
            _flangeOtherController.text.trim().isEmpty) {
          _showError('Please specify flange quantity for OTHERS.');
          return false;
        }

        _formData.flangeQuantityOther = _formData.flangeQuantity == 'OTHERS'
            ? _flangeOtherController.text.trim()
            : null;
        return true;
      case 10:
        if (_requiresRefusalForm && _formData.refusalImages.isEmpty) {
          _showError('Please upload the refusal form before submitting.');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _captureImage(String imageType, ImageSource source) async {
    final images = _imagesForType(imageType);
    if (images.length >= _maxImagesPerSection) {
      _showError(
        'Maximum of $_maxImagesPerSection images only for this section.',
      );
      return;
    }

    try {
      setState(() {
        _setUploadingState(imageType, true);
      });

      final imageData = await _imageCaptureService.captureWithGps(
        source: source,
        installerName: _formData.fullName,
        completeAddress: _formData.completeAddress,
      );
      if (!mounted || imageData == null) return;

      setState(() {
        if (images.length < _maxImagesPerSection) {
          images.add(imageData);
        }
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _setUploadingState(imageType, false);
        });
      }
    }
  }

  List<CapturedImageData> _imagesForType(String imageType) {
    switch (imageType) {
      case 'before':
        return _formData.beforeImages;
      case 'after':
        return _formData.afterImages;
      case 'completion':
        return _formData.completionImages;
      case 'refusal':
        return _formData.refusalImages;
      default:
        return _formData.beforeImages;
    }
  }

  void _setUploadingState(String imageType, bool value) {
    if (imageType == 'before') _isUploadingBefore = value;
    if (imageType == 'after') _isUploadingAfter = value;
    if (imageType == 'completion') _isUploadingCompletion = value;
    if (imageType == 'refusal') _isUploadingRefusal = value;
  }

  void _removeImageAt(String imageType, int index) {
    final images = _imagesForType(imageType);
    if (index < 0 || index >= images.length) return;

    setState(() {
      images.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages(List<CapturedImageData> images) async {
    final uploadedUrls = <String>[];
    for (final image in images) {
      uploadedUrls.add(await _uploadService.uploadImageToGoogleDrive(image));
    }
    return uploadedUrls;
  }

  String _joinUploadedUrls(List<String> urls) {
    return urls
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .join('\n');
  }

  Future<void> _submit() async {
    if (_formData.beforeImages.isEmpty ||
        _formData.afterImages.isEmpty ||
        _formData.completionImages.isEmpty) {
      _showError('Please upload all required images before submitting.');
      return;
    }

    if (_requiresRefusalForm && _formData.refusalImages.isEmpty) {
      _showError('Please upload the refusal form before submitting.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final beforeUrls = await _uploadImages(_formData.beforeImages);
      final afterUrls = await _uploadImages(_formData.afterImages);
      final completionUrls = await _uploadImages(_formData.completionImages);
      final refusalUrls = _formData.refusalImages.isEmpty
          ? const <String>[]
          : await _uploadImages(_formData.refusalImages);

      final payload = _formData.toJson()
        ..addAll({
          'beforeImageDriveUrl': _joinUploadedUrls(beforeUrls),
          'afterImageDriveUrl': _joinUploadedUrls(afterUrls),
          'completionImageDriveUrl': _joinUploadedUrls(completionUrls),
          'refusalImageDriveUrl': _joinUploadedUrls(refusalUrls),
          'beforeImageDriveUrls': beforeUrls,
          'afterImageDriveUrls': afterUrls,
          'completionImageDriveUrls': completionUrls,
          'refusalImageDriveUrls': refusalUrls,
        });

      if (_isEditMode) {
        final initialSubmission = widget.initialSubmission;
        final rowNumber = initialSubmission?.rowNumber;
        if (initialSubmission == null || rowNumber == null || rowNumber <= 1) {
          throw Exception(
            'Unable to update this submission. Missing row reference.',
          );
        }

        await _uploadService.updateGoogleSheetsEntry(
          payload: payload,
          branch: initialSubmission.branch,
          rowNumber: rowNumber,
          originalTimestamp: initialSubmission.scriptTimestamp.trim().isNotEmpty
              ? initialSubmission.scriptTimestamp
              : initialSubmission.timestamp,
          originalOutletCode: initialSubmission.outletCode,
          originalInstallerName: initialSubmission.fullName,
        );
      } else {
        await _uploadService.submitToGoogleSheets(payload);
      }

      await _localStorageService.clearDraft();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Success'),
            content: Text(
              _isEditMode
                  ? 'Submission updated successfully.'
                  : 'Form submitted successfully.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (_isEditMode) {
        Navigator.of(context).pop(true);
        return;
      }

      await _resetFormToFirstStep();
    } catch (e) {
      await _localStorageService.saveDraft(_formData.toJson());
      if (!mounted) return;
      _showError('Upload failed. Draft saved locally. $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _resetFormToFirstStep() async {
    _formData.branch = null;
    _formData.fullName = null;
    _formData.outletCode = null;
    _formData.signageName = null;
    _formData.storeOwnerName = null;
    _formData.completeAddress = null;
    _formData.brands.clear();
    _formData.signageQuantity = null;
    _formData.signageQuantityOther = null;
    _formData.awningQuantity = null;
    _formData.awningQuantityOther = null;
    _formData.flangeQuantity = null;
    _formData.flangeQuantityOther = null;
    _formData.beforeImages.clear();
    _formData.afterImages.clear();
    _formData.completionImages.clear();
    _formData.refusalImages.clear();

    _fullNameController.clear();
    _outletCodeController.clear();
    _signageNameController.clear();
    _storeOwnerController.clear();
    _purokController.clear();
    _selectedBarangay = null;
    _selectedMunicipality = null;
    _municipalityController.clear();
    _barangayController.clear();
    _signageOtherController.clear();
    _awningOtherController.clear();
    _flangeOtherController.clear();
    await _localStorageService.clearDraft();

    if (!mounted) return;

    setState(() {
      _currentStep = 0;
    });

    await _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildBranchStep() {
    if (_isBootstrappingForm) {
      return const StepCard(
        title: 'Select Branch',
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Preparing form data...'),
          ],
        ),
      );
    }

    if (_isLocationCatalogLoading) {
      return const StepCard(
        title: 'Select Branch',
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading branch and location data...'),
          ],
        ),
      );
    }

    if (_locationCatalogError != null) {
      return StepCard(
        title: 'Select Branch',
        child: Column(
          children: [
            Text(
              _locationCatalogError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            PrimaryActionButton(
                label: 'RETRY', onPressed: _loadLocationCatalog),
          ],
        ),
      );
    }

    final selectedBranch =
        _branches.contains(_formData.branch) ? _formData.branch : null;

    return StepCard(
      title: 'Select Branch',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedBranch,
            decoration: InputDecoration(
              hintText: 'Select branch',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
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
            onChanged:
                _branches.isEmpty || _isEditMode || _hasLockedInstallerProfile
                    ? null
                    : (value) {
                        setState(() {
                          _formData.branch = value;
                          _selectedMunicipality = null;
                          _selectedBarangay = null;
                          _formData.municipality = null;
                          _formData.barangay = null;
                          _municipalityController.clear();
                          _barangayController.clear();
                        });
                      },
          ),
          if (_branches.isEmpty) ...[
            const SizedBox(height: 12),
            const Text('No branch data found in location catalog.'),
          ],
          const SizedBox(height: 20),
          PrimaryActionButton(
            label: 'NEXT',
            onPressed: _branches.isEmpty ? null : _goNext,
          ),
        ],
      ),
    );
  }

  Widget _buildTextStep({
    required String title,
    required TextEditingController controller,
    required String buttonLabel,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return StepCard(
      title: title,
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: maxLines,
            enabled: enabled,
            decoration: InputDecoration(
              hintText: 'Enter $title',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryActionButton(label: buttonLabel, onPressed: _goNext),
        ],
      ),
    );
  }

  Widget _buildQuantityStep({
    required String title,
    required String? value,
    required TextEditingController otherController,
    required void Function(String?) onChanged,
  }) {
    return StepCard(
      title: title,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              hintText: 'Select quantity',
            ),
            items: _quantityOptions
                .map((option) => DropdownMenuItem(
                      value: option,
                      child: Text(option),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
          if (value == 'OTHERS') ...[
            const SizedBox(height: 12),
            TextField(
              controller: otherController,
              decoration: InputDecoration(
                hintText: 'Please specify',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          PrimaryActionButton(label: 'CONFIRM', onPressed: _goNext),
        ],
      ),
    );
  }

  List<String> _municipalityOptions() {
    final branch = _formData.branch;
    if (branch == null || branch.isEmpty) return const <String>[];

    final municipalities = <String>{
      ...(_branchMunicipalities[branch] ?? const <String>[]),
    };

    return municipalities.toList()..sort();
  }

  List<String> _barangayOptions({String? municipality}) {
    final branch = _formData.branch;
    final branchMap = branch == null
        ? const <String, List<String>>{}
        : (_branchMunicipalityBarangays[branch] ??
            const <String, List<String>>{});

    if (municipality != null && municipality.isNotEmpty) {
      return branchMap[municipality] ?? const [];
    }

    final barangays = <String>{};

    for (final item in _municipalityOptions()) {
      barangays.addAll(branchMap[item] ?? const <String>[]);
    }

    return barangays.toList()..sort();
  }

  Widget _buildLocationStep() {
    final municipalities = _municipalityOptions();
    final selectedMunicipality = _resolveTypedSelection(
      _municipalityController,
      municipalities,
      currentValue: _selectedMunicipality,
    );
    final barangays = _barangayOptions(municipality: selectedMunicipality);
    final selectedBarangay = _resolveTypedSelection(
      _barangayController,
      barangays,
      currentValue: _selectedBarangay,
    );

    return StepCard(
      title: 'LOCATION DETAILS',
      child: Column(
        children: [
          _buildSearchableOptionField(
            fieldKey: ValueKey(
              'municipality-${_formData.branch ?? ''}-${selectedMunicipality ?? _municipalityController.text}-${municipalities.length}',
            ),
            controller: _municipalityController,
            hintText: 'Select or type Municipality',
            options: municipalities,
            onSelected: (value) {
              setState(() {
                _selectedMunicipality = value;
                _selectedBarangay = null;
                _barangayController.clear();
              });
            },
          ),
          const SizedBox(height: 12),
          _buildSearchableOptionField(
            fieldKey: ValueKey(
              'barangay-${selectedMunicipality ?? ''}-${selectedBarangay ?? _barangayController.text}-${barangays.length}',
            ),
            controller: _barangayController,
            hintText: 'Select or type Barangay',
            options: barangays,
            enabled: selectedMunicipality != null,
            onSelected: (value) {
              setState(() {
                _selectedBarangay = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _purokController,
            decoration: InputDecoration(
              hintText: 'Enter Purok',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 20),
          PrimaryActionButton(label: 'NEXT', onPressed: _goNext),
        ],
      ),
    );
  }

  Widget _buildSearchableOptionField({
    required Key fieldKey,
    required TextEditingController controller,
    required String hintText,
    required List<String> options,
    required ValueChanged<String?> onSelected,
    bool enabled = true,
  }) {
    return Autocomplete<String>(
      key: fieldKey,
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (textEditingValue) {
        if (!enabled) return const Iterable<String>.empty();

        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return options;

        return options.where(
          (option) => option.toLowerCase().contains(query),
        );
      },
      onSelected: (selection) {
        controller.text = selection;
        onSelected(selection);
      },
      fieldViewBuilder: (
        context,
        textEditingController,
        focusNode,
        onFieldSubmitted,
      ) {
        if (textEditingController.text != controller.text) {
          textEditingController.value = TextEditingValue(
            text: controller.text,
            selection: TextSelection.collapsed(offset: controller.text.length),
          );
        }

        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          enabled: enabled,
          onChanged: (value) {
            controller.value = textEditingController.value;
          },
          onSubmitted: (_) {
            controller.value = textEditingController.value;
            onFieldSubmitted();
          },
          decoration: InputDecoration(
            hintText: enabled ? hintText : 'Select Municipality first',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, filteredOptions) {
        final items = filteredOptions.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 280),
              child: items.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No matching results.'),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return ListTile(
                          dense: true,
                          title: Text(item),
                          onTap: () => onSelected(item),
                        );
                      },
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadSection({
    required String title,
    required List<CapturedImageData> images,
    required bool isUploading,
    required VoidCallback onCameraUpload,
    required VoidCallback onAlbumUpload,
    required void Function(int index) onRemoveImage,
  }) {
    final canAddMore = images.length < _maxImagesPerSection;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              images.isEmpty
                  ? 'No image captured yet.'
                  : '${images.length} of $_maxImagesPerSection images uploaded.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              canAddMore
                  ? 'You can upload ${_maxImagesPerSection - images.length} more image${_maxImagesPerSection - images.length == 1 ? '' : 's'}.'
                  : 'Upload limit reached for this section.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: canAddMore ? Colors.black54 : Colors.orange.shade800,
              ),
            ),
            if (images.isNotEmpty) const SizedBox(height: 10),
            if (images.isNotEmpty)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (var index = 0; index < images.length; index++)
                    _buildCapturedImageTile(
                      imageData: images[index],
                      onRemove: () => onRemoveImage(index),
                    ),
                ],
              ),
            if (images.isNotEmpty) const SizedBox(height: 10),
            Text(
              images.isEmpty
                  ? 'Capture or select up to $_maxImagesPerSection images.'
                  : 'Latest GPS: ${images.last.latitude.toStringAsFixed(6)}, ${images.last.longitude.toStringAsFixed(6)}',
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: 220,
                    child: PrimaryActionButton(
                      label: 'USE CAMERA',
                      onPressed: canAddMore ? onCameraUpload : null,
                      isLoading: isUploading,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: PrimaryActionButton(
                      label: 'UPLOAD FROM ALBUM',
                      onPressed: canAddMore ? onAlbumUpload : null,
                      isLoading: isUploading,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapturedImageTile({
    required CapturedImageData imageData,
    required VoidCallback onRemove,
  }) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(imageData.filePath),
              height: 120,
              width: 160,
              fit: BoxFit.cover,
              cacheWidth: 720,
              filterQuality: FilterQuality.low,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 120,
                  width: 160,
                  alignment: Alignment.center,
                  color: Colors.black12,
                  child: const Text('Unable to preview image'),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'GPS: ${imageData.latitude.toStringAsFixed(4)}, ${imageData.longitude.toStringAsFixed(4)}',
            style: const TextStyle(fontSize: 11),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Remove'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progressText = 'Step ${_currentStep + 1} of 11';
    final branchLabel = _formData.branch?.trim().isNotEmpty == true
        ? _formData.branch!
        : 'Not selected';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back',
          ),
          title: const Text('R.C. MACAPAGAL GFORM'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    progressText,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Branch: $branchLabel',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildBranchStep(),
                    _buildTextStep(
                      title: 'INSTALLER NAME',
                      controller: _fullNameController,
                      buttonLabel: 'NEXT',
                      enabled: !_hasLockedInstallerProfile,
                    ),
                    _buildTextStep(
                      title: 'OUTLET CODE',
                      controller: _outletCodeController,
                      buttonLabel: 'NEXT',
                    ),
                    _buildTextStep(
                      title: 'STORE NAME',
                      controller: _signageNameController,
                      buttonLabel: 'NEXT',
                    ),
                    _buildTextStep(
                      title: 'STORE OWNER NAME',
                      controller: _storeOwnerController,
                      buttonLabel: 'NEXT',
                    ),
                    _buildLocationStep(),
                    StepCard(
                      title: 'BRAND SELECTION',
                      child: Column(
                        children: [
                          ..._brands.map(
                            (brand) {
                              final selected = _formData.brands.contains(brand);
                              return Card(
                                elevation: 0,
                                color: selected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primaryContainer
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: selected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: CheckboxListTile(
                                  value: selected,
                                  title: Text(
                                    brand,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  onChanged: (isChecked) {
                                    setState(() {
                                      if (isChecked == true) {
                                        _formData.brands.add(brand);
                                      } else {
                                        _formData.brands.remove(brand);
                                      }
                                    });
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          PrimaryActionButton(
                            label: 'CONFIRM',
                            onPressed: _goNext,
                          ),
                        ],
                      ),
                    ),
                    _buildQuantityStep(
                      title: 'QUANTITY OF SIGNAGE',
                      value: _formData.signageQuantity,
                      otherController: _signageOtherController,
                      onChanged: (value) {
                        setState(() {
                          _formData.signageQuantity = value;
                          if (value != 'OTHERS') {
                            _signageOtherController.clear();
                            _formData.signageQuantityOther = null;
                          }
                        });
                      },
                    ),
                    _buildQuantityStep(
                      title: 'QUANTITY OF AWNINGS',
                      value: _formData.awningQuantity,
                      otherController: _awningOtherController,
                      onChanged: (value) {
                        setState(() {
                          _formData.awningQuantity = value;
                          if (value != 'OTHERS') {
                            _awningOtherController.clear();
                            _formData.awningQuantityOther = null;
                          }
                        });
                      },
                    ),
                    _buildQuantityStep(
                      title: 'QUANTITY OF FLANGE',
                      value: _formData.flangeQuantity,
                      otherController: _flangeOtherController,
                      onChanged: (value) {
                        setState(() {
                          _formData.flangeQuantity = value;
                          if (value != 'OTHERS') {
                            _flangeOtherController.clear();
                            _formData.flangeQuantityOther = null;
                          }
                        });
                      },
                    ),
                    StepCard(
                      title: 'GDRIVE UPLOADER',
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildUploadSection(
                              title: 'BEFORE (WITH GPS)',
                              images: _formData.beforeImages,
                              isUploading: _isUploadingBefore,
                              onCameraUpload: () =>
                                  _captureImage('before', ImageSource.camera),
                              onAlbumUpload: () =>
                                  _captureImage('before', ImageSource.gallery),
                              onRemoveImage: (index) =>
                                  _removeImageAt('before', index),
                            ),
                            const SizedBox(height: 12),
                            _buildUploadSection(
                              title: 'AFTER (WITH GPS)',
                              images: _formData.afterImages,
                              isUploading: _isUploadingAfter,
                              onCameraUpload: () =>
                                  _captureImage('after', ImageSource.camera),
                              onAlbumUpload: () =>
                                  _captureImage('after', ImageSource.gallery),
                              onRemoveImage: (index) =>
                                  _removeImageAt('after', index),
                            ),
                            const SizedBox(height: 12),
                            _buildUploadSection(
                              title: 'COMPLETION FORM',
                              images: _formData.completionImages,
                              isUploading: _isUploadingCompletion,
                              onCameraUpload: () => _captureImage(
                                  'completion', ImageSource.camera),
                              onAlbumUpload: () => _captureImage(
                                  'completion', ImageSource.gallery),
                              onRemoveImage: (index) =>
                                  _removeImageAt('completion', index),
                            ),
                            const SizedBox(height: 12),
                            _buildUploadSection(
                              title: _requiresRefusalForm
                                  ? 'REFUSAL FORM (REQUIRED)'
                                  : 'REFUSAL FORM (OPTIONAL)',
                              images: _formData.refusalImages,
                              isUploading: _isUploadingRefusal,
                              onCameraUpload: () =>
                                  _captureImage('refusal', ImageSource.camera),
                              onAlbumUpload: () =>
                                  _captureImage('refusal', ImageSource.gallery),
                              onRemoveImage: (index) =>
                                  _removeImageAt('refusal', index),
                            ),
                            const SizedBox(height: 16),
                            PrimaryActionButton(
                              label: _isEditMode
                                  ? 'UPDATE & REUPLOAD'
                                  : 'SUBMIT FORM',
                              onPressed: _isSubmitting ? null : _submit,
                              isLoading: _isSubmitting,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantitySelection {
  const _QuantitySelection({
    required this.selection,
    required this.otherValue,
  });

  final String? selection;
  final String? otherValue;
}
