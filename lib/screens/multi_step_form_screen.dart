import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/captured_image_data.dart';
import '../models/installation_form_data.dart';
import '../services/image_capture_service.dart';
import '../services/local_storage_service.dart';
import '../services/location_catalog_service.dart';
import '../services/upload_service.dart';
import '../widgets/primary_action_button.dart';
import '../widgets/step_card.dart';

class MultiStepFormScreen extends StatefulWidget {
  const MultiStepFormScreen({super.key});

  @override
  State<MultiStepFormScreen> createState() => _MultiStepFormScreenState();
}

class _MultiStepFormScreenState extends State<MultiStepFormScreen> {
  static const List<String> _brands = ['CAMEL', 'WINSTON', 'MIGHTY'];

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
  final TextEditingController _signageOtherController = TextEditingController();
  final TextEditingController _awningOtherController = TextEditingController();
  final TextEditingController _flangeOtherController = TextEditingController();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _isUploadingBefore = false;
  bool _isUploadingAfter = false;
  bool _isUploadingCompletion = false;
  bool _isLocationCatalogLoading = true;
  String? _locationCatalogError;
  String? _selectedMunicipality;
  String? _selectedBarangay;

  List<String> _branches = const <String>[];
  Map<String, List<String>> _branchMunicipalities =
      const <String, List<String>>{};
  Map<String, Map<String, List<String>>> _branchMunicipalityBarangays =
      const <String, Map<String, List<String>>>{};

  @override
  void initState() {
    super.initState();
    _loadLocationCatalog();
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
    _pageController.dispose();
    _fullNameController.dispose();
    _outletCodeController.dispose();
    _signageNameController.dispose();
    _storeOwnerController.dispose();
    _purokController.dispose();
    _signageOtherController.dispose();
    _awningOtherController.dispose();
    _flangeOtherController.dispose();
    super.dispose();
  }

  Future<void> _goNext() async {
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
        if (_selectedMunicipality == null || _selectedMunicipality!.isEmpty) {
          _showError('Please select a municipality.');
          return false;
        }

        if (_selectedBarangay == null || _selectedBarangay!.isEmpty) {
          _showError('Please select a barangay.');
          return false;
        }

        if (_purokController.text.trim().isEmpty) {
          _showError('Purok is required.');
          return false;
        }

        _formData.purok = _purokController.text.trim();
        _formData.barangay = _selectedBarangay;
        _formData.municipality = _selectedMunicipality;
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
        return true;
      default:
        return true;
    }
  }

  Future<void> _captureImage(String imageType, ImageSource source) async {
    try {
      setState(() {
        if (imageType == 'before') _isUploadingBefore = true;
        if (imageType == 'after') _isUploadingAfter = true;
        if (imageType == 'completion') _isUploadingCompletion = true;
      });

      final imageData = await _imageCaptureService.captureWithGps(
        source: source,
        installerName: _formData.fullName,
        completeAddress: _formData.completeAddress,
      );
      if (!mounted || imageData == null) return;

      setState(() {
        if (imageType == 'before') _formData.beforeImage = imageData;
        if (imageType == 'after') _formData.afterImage = imageData;
        if (imageType == 'completion') _formData.completionImage = imageData;
      });
    } catch (e) {
      if (!mounted) return;
      _showError(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          if (imageType == 'before') _isUploadingBefore = false;
          if (imageType == 'after') _isUploadingAfter = false;
          if (imageType == 'completion') _isUploadingCompletion = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_formData.beforeImage == null ||
        _formData.afterImage == null ||
        _formData.completionImage == null) {
      _showError('Please upload all required images before submitting.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final beforeUrl =
          await _uploadService.uploadImageToGoogleDrive(_formData.beforeImage!);
      final afterUrl =
          await _uploadService.uploadImageToGoogleDrive(_formData.afterImage!);
      final completionUrl = await _uploadService
          .uploadImageToGoogleDrive(_formData.completionImage!);

      final payload = _formData.toJson()
        ..addAll({
          'beforeImageDriveUrl': beforeUrl,
          'afterImageDriveUrl': afterUrl,
          'completionImageDriveUrl': completionUrl,
        });

      await _uploadService.submitToGoogleSheets(payload);
      await _localStorageService.clearDraft();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Success'),
            content: const Text('Form submitted successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );

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
    _formData.beforeImage = null;
    _formData.afterImage = null;
    _formData.completionImage = null;

    _fullNameController.clear();
    _outletCodeController.clear();
    _signageNameController.clear();
    _storeOwnerController.clear();
    _purokController.clear();
    _selectedBarangay = null;
    _selectedMunicipality = null;
    _signageOtherController.clear();
    _awningOtherController.clear();
    _flangeOtherController.clear();

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
            onChanged: _branches.isEmpty
                ? null
                : (value) {
                    setState(() {
                      _formData.branch = value;
                      _selectedMunicipality = null;
                      _selectedBarangay = null;
                      _formData.municipality = null;
                      _formData.barangay = null;
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
  }) {
    return StepCard(
      title: title,
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: maxLines,
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
    final selectedMunicipality = municipalities.contains(_selectedMunicipality)
        ? _selectedMunicipality
        : null;
    final barangays = _barangayOptions(municipality: selectedMunicipality);
    final selectedBarangay =
        barangays.contains(_selectedBarangay) ? _selectedBarangay : null;

    return StepCard(
      title: 'LOCATION DETAILS',
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedMunicipality,
            decoration: InputDecoration(
              hintText: 'Select Municipality',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: municipalities
                .map((municipality) => DropdownMenuItem(
                    value: municipality, child: Text(municipality)))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedMunicipality = value;
                _selectedBarangay = null;
              });
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: selectedBarangay,
            decoration: InputDecoration(
              hintText: 'Select Barangay',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: barangays
                .map((barangay) =>
                    DropdownMenuItem(value: barangay, child: Text(barangay)))
                .toList(),
            onChanged: (value) {
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

  Widget _buildUploadSection({
    required String title,
    required CapturedImageData? imageData,
    required bool isUploading,
    required VoidCallback onCameraUpload,
    required VoidCallback onAlbumUpload,
  }) {
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
            if (imageData != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  File(imageData.filePath),
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  cacheWidth: 1080,
                  filterQuality: FilterQuality.low,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      width: double.infinity,
                      alignment: Alignment.center,
                      color: Colors.black12,
                      child: const Text('Unable to preview image'),
                    );
                  },
                ),
              ),
            if (imageData != null) const SizedBox(height: 10),
            Text(
              imageData == null
                  ? 'No image captured yet.'
                  : 'GPS: ${imageData.latitude.toStringAsFixed(6)}, ${imageData.longitude.toStringAsFixed(6)}',
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
                      onPressed: onCameraUpload,
                      isLoading: isUploading,
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: PrimaryActionButton(
                      label: 'UPLOAD FROM ALBUM',
                      onPressed: onAlbumUpload,
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

  @override
  Widget build(BuildContext context) {
    final progressText = 'Step ${_currentStep + 1} of 11';
    final branchLabel = _formData.branch?.trim().isNotEmpty == true
        ? _formData.branch!
        : 'Not selected';

    return Scaffold(
      appBar: AppBar(
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
                            imageData: _formData.beforeImage,
                            isUploading: _isUploadingBefore,
                            onCameraUpload: () =>
                                _captureImage('before', ImageSource.camera),
                            onAlbumUpload: () =>
                                _captureImage('before', ImageSource.gallery),
                          ),
                          const SizedBox(height: 12),
                          _buildUploadSection(
                            title: 'AFTER (WITH GPS)',
                            imageData: _formData.afterImage,
                            isUploading: _isUploadingAfter,
                            onCameraUpload: () =>
                                _captureImage('after', ImageSource.camera),
                            onAlbumUpload: () =>
                                _captureImage('after', ImageSource.gallery),
                          ),
                          const SizedBox(height: 12),
                          _buildUploadSection(
                            title: 'COMPLETION FORM',
                            imageData: _formData.completionImage,
                            isUploading: _isUploadingCompletion,
                            onCameraUpload: () =>
                                _captureImage('completion', ImageSource.camera),
                            onAlbumUpload: () => _captureImage(
                                'completion', ImageSource.gallery),
                          ),
                          const SizedBox(height: 16),
                          PrimaryActionButton(
                            label: 'SUBMIT FORM',
                            onPressed: _submit,
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
    );
  }
}
