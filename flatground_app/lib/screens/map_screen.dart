import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;

import '../models/skate_spot.dart';
import '../services/skate_spot_api.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    SkateSpotApi? spotApi,
    loc.Location? locationService,
    this.enableLocation = true,
  })  : _spotApi = spotApi,
        _locationService = locationService;

  final SkateSpotApi? _spotApi;
  final loc.Location? _locationService;
  final bool enableLocation;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const List<String> _defaultSpotTypes = <String>[
    'Ledge',
    'Skatepark',
    'Plaza',
    'Stairs',
    'Hubba',
    'Rail',
    'Bowl',
    'Mini ramp',
    'Flat',
    'Bench',
    'Curb',
    'Manny pad',
    'Bank',
    'Gap',
  ];

  final MapController _mapController = MapController();
  loc.LocationData? _currentLocation;
  final ImagePicker _imagePicker = ImagePicker();
  late final loc.Location _locationService;
  late final SkateSpotApi _spotApi;
  List<SkateSpot> _skateSpots = [];
  final Set<String> _sessionCreatedSpotIds = <String>{};
  LatLng? _temporaryPinPosition;
  bool _isListFullscreen = false;
  bool _showFilterPanel = false;
  bool _isLoadingSpots = true;
  String? _spotsError;
  final Set<String> _selectedTypeFilters = <String>{};

  @override
  void initState() {
    super.initState();
    _locationService = widget._locationService ?? loc.Location();
    _spotApi = widget._spotApi ?? SkateSpotApi();
    if (widget.enableLocation) {
      _initializeLocation();
    }
    _loadSkateSpots();
    Future.microtask(_loadSkateSpots);
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          _showLocationMessage('Location service is disabled.');
          return;
        }
      }

      loc.PermissionStatus permissionGranted = await _locationService.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await _locationService.requestPermission();
      }
      if (permissionGranted == loc.PermissionStatus.deniedForever) {
        _showLocationMessage(
          'Location permission is permanently denied. Enable it in app settings.',
        );
        return;
      }
      if (permissionGranted != loc.PermissionStatus.granted) {
        _showLocationMessage('Location permission was not granted.');
        return;
      }

      _currentLocation = await _locationService.getLocation();
      if (!mounted) return;
      if (_currentLocation != null) {
        _mapController.move(
          LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
          13.0,
        );
      }
    } catch (_) {
      _showLocationMessage('Could not determine location on this device.');
    }
  }

  void _showLocationMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _goToCurrentLocation() async {
    await _initializeLocation();
    if (!mounted || _currentLocation == null) {
      return;
    }
    _mapController.move(
      LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
      15.0,
    );
  }

  Future<void> _loadSkateSpots() async {
    setState(() {
      _isLoadingSpots = true;
      _spotsError = null;
    });

    try {
      final spots = await _spotApi.fetchSpots();
      if (!mounted) return;
      setState(() {
        _skateSpots = spots;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _spotsError = 'Could not load skate spots.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSpots = false;
        });
      }
    }
  }

  Set<String> _parseTypes(String encoded) {
    return encoded
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toSet();
  }

  String _encodeTypes(Set<String> selected) {
    final sorted = selected.toList()..sort();
    return sorted.join(', ');
  }

  List<String> _allKnownTypes() {
    final merged = <String>{..._defaultSpotTypes};
    for (final spot in _skateSpots) {
      merged.addAll(_parseTypes(spot.type));
    }
    final result = merged.toList()..sort();
    return result;
  }

  void _openPhotoViewer(String photoUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                _spotApi.resolvePhotoUrl(photoUrl),
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<SkateSpot> get _visibleSpots {
    final filtered = _selectedTypeFilters.isEmpty
        ? _skateSpots
        : _skateSpots
            .where((spot) => _parseTypes(spot.type).any(_selectedTypeFilters.contains))
            .toList();
    return _sortByProximity(filtered);
  }

  List<SkateSpot> _sortByProximity(List<SkateSpot> spots) {
    final userLat = _currentLocation?.latitude;
    final userLng = _currentLocation?.longitude;
    if (userLat == null || userLng == null) {
      return spots;
    }
    final sorted = [...spots];
    sorted.sort((a, b) {
      final da = const Distance().as(
        LengthUnit.Meter,
        LatLng(userLat, userLng),
        LatLng(a.latitude, a.longitude),
      );
      final db = const Distance().as(
        LengthUnit.Meter,
        LatLng(userLat, userLng),
        LatLng(b.latitude, b.longitude),
      );
      return da.compareTo(db);
    });
    return sorted;
  }

  Future<String> _getAddressFromCoordinates(LatLng position) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        final place = placemarks[0];
        final addressParts = <String>[];
        
        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }
        
        return addressParts.isNotEmpty 
            ? addressParts.join(', ')
            : '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      }
    } catch (e) {
      print('Error getting address: $e');
    }
    
    return '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
  }

  Future<LatLng?> _pickSpotPosition(LatLng initialPosition) async {
    LatLng selected = initialPosition;
    return showDialog<LatLng>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Adjust spot pin',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: 320,
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: initialPosition,
                  initialZoom: 16,
                  onTap: (_, point) {
                    setDialogState(() {
                      selected = point;
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.flatground_app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: selected,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFC7C1E4),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(
                            Icons.place,
                            color: Color(0xFF2F00FF),
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, selected),
              child: const Text('Use this pin'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSpotDialog(LatLng position) async {
    final nameController = TextEditingController();
    final customTypeController = TextEditingController();
    final addressController = TextEditingController();
    final descriptionController = TextEditingController();
    List<File> selectedPhotos = [];
    final selectedTypes = <String>{};
    String selectedDifficulty = 'beginner';
    bool isSubmitting = false;

    LatLng selectedPosition = position;
    final address = await _getAddressFromCoordinates(selectedPosition);
    if (!mounted) return;
    addressController.text = address;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'Add Skate Spot',
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: const Color(0xFF2F00FF),
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    labelStyle: GoogleFonts.poppins(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Types (select one or more)',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: const Color(0xFF2F00FF),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (({..._allKnownTypes(), ...selectedTypes}.toList()..sort()).map(
                        (type) => FilterChip(
                          label: Text(type),
                          selected: selectedTypes.contains(type),
                          onSelected: (enabled) {
                            setDialogState(() {
                              if (enabled) {
                                selectedTypes.add(type);
                              } else {
                                selectedTypes.remove(type);
                              }
                            });
                          },
                        ),
                      )).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: customTypeController,
                  maxLength: 50,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Add custom type',
                    labelStyle: GoogleFonts.poppins(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      final customType = customTypeController.text.trim();
                      if (customType.isEmpty || customType.length > 50) {
                        return;
                      }
                      setDialogState(() {
                        selectedTypes.add(customType);
                        customTypeController.clear();
                      });
                    },
                    child: const Text('Add type'),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedDifficulty,
                  decoration: InputDecoration(
                    labelText: 'Difficulty',
                    labelStyle: GoogleFonts.poppins(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                    DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
                    DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      selectedDifficulty = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  readOnly: true,
                  onTap: () async {
                    final picked = await _pickSpotPosition(selectedPosition);
                    if (picked == null) return;
                    selectedPosition = picked;
                    final updatedAddress = await _getAddressFromCoordinates(selectedPosition);
                    if (!mounted) return;
                    setDialogState(() {
                      addressController.text = updatedAddress;
                    });
                  },
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Address (tap to reposition pin)',
                    labelStyle: GoogleFonts.poppins(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  style: GoogleFonts.poppins(fontSize: 14),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    labelStyle: GoogleFonts.poppins(fontSize: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                // Photo upload section
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Photos',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF2F00FF),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        try {
                          final XFile? image = await _imagePicker.pickImage(
                            source: ImageSource.gallery,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setDialogState(() {
                              selectedPhotos.add(File(image.path));
                            });
                          }
                        } catch (e) {
                          print('Error picking image: $e');
                        }
                      },
                      icon: const Icon(Icons.add_photo_alternate, color: Color(0xFF2F00FF)),
                      tooltip: 'Add photo from gallery',
                    ),
                    IconButton(
                      onPressed: () async {
                        try {
                          final XFile? image = await _imagePicker.pickImage(
                            source: ImageSource.camera,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setDialogState(() {
                              selectedPhotos.add(File(image.path));
                            });
                          }
                        } catch (e) {
                          print('Error taking photo: $e');
                        }
                      },
                      icon: const Icon(Icons.camera_alt, color: Color(0xFF2F00FF)),
                      tooltip: 'Take photo',
                    ),
                  ],
                ),
                if (selectedPhotos.isNotEmpty)
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedPhotos.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: FileImage(selectedPhotos[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedPhotos.removeAt(index);
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _temporaryPinPosition = null; // Clear temporary pin on cancel
                });
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                if (nameController.text.isNotEmpty &&
                    selectedTypes.isNotEmpty &&
                    addressController.text.isNotEmpty) {
                  setDialogState(() {
                    isSubmitting = true;
                  });
                  SkateSpot? createdSpot;
                  try {
                    createdSpot = await _spotApi.createSpot(
                      SkateSpot(
                    id: '',
                    name: nameController.text,
                    type: _encodeTypes(selectedTypes),
                    address: addressController.text,
                    latitude: selectedPosition.latitude,
                    longitude: selectedPosition.longitude,
                    difficulty: selectedDifficulty,
                    description: descriptionController.text.isEmpty
                        ? null
                        : descriptionController.text,
                      ),
                    );
                    _sessionCreatedSpotIds.add(createdSpot.id);
                    if (selectedPhotos.isNotEmpty) {
                      try {
                        await _spotApi.uploadPhotos(
                          spotId: createdSpot.id,
                          files: selectedPhotos,
                        );
                      } catch (uploadError) {
                        await _spotApi.deleteSpot(createdSpot.id);
                        _sessionCreatedSpotIds.remove(createdSpot.id);
                        throw Exception('Photo upload failed and spot was rolled back: $uploadError');
                      }
                    }
                    await _loadSkateSpots();
                    if (!mounted) return;
                    setState(() {
                      _temporaryPinPosition = null;
                    });
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  } catch (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text('Could not save skate spot: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    setDialogState(() {
                      isSubmitting = false;
                    });
                  }
                }
              },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2F00FF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Add',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Future<void> _deleteSessionSpot(SkateSpot spot) async {
    try {
      await _spotApi.deleteSpot(spot.id);
      _sessionCreatedSpotIds.remove(spot.id);
      await _loadSkateSpots();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spot deleted')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete spot: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSpotDetails(SkateSpot spot) {
    final canDelete = true;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(40),
            topRight: Radius.circular(40),
          ),
        ),
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    spot.name,
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      color: const Color(0xFF2F00FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _showEditSpotDialog(spot);
                  },
                  icon: const Icon(Icons.edit, color: Color(0xFF2F00FF)),
                  tooltip: 'Edit title and description',
                ),
                if (canDelete)
                  IconButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _deleteSessionSpot(spot);
                    },
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete spot',
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              spot.type,
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: const Color(0xFF2F00FF).withOpacity(0.7),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Difficulty: ${spot.difficulty}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF180081).withOpacity(0.65),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              spot.address,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF180081).withOpacity(0.44),
                fontWeight: FontWeight.w300,
              ),
            ),
            if (spot.description != null) ...[
              const SizedBox(height: 16),
              Text(
                spot.description!,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
            if (spot.photoUrls.isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: spot.photoUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final resolved = _spotApi.resolvePhotoUrl(spot.photoUrls[index]);
                    return GestureDetector(
                      onTap: () => _openPhotoViewer(spot.photoUrls[index]),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          resolved,
                          width: 140,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 140,
                            height: 110,
                            color: const Color(0xFFC7C1E4),
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image, color: Colors.white),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditSpotDialog(SkateSpot spot) async {
    final nameController = TextEditingController(text: spot.name);
    final customTypeController = TextEditingController();
    final addressController = TextEditingController(text: spot.address);
    final descriptionController = TextEditingController(text: spot.description ?? '');
    final selectedTypes = _parseTypes(spot.type);
    final photos = List<SpotPhotoRef>.from(spot.photos);
    LatLng selectedPosition = LatLng(spot.latitude, spot.longitude);
    bool pinWasUpdated = false;
    String selectedDifficulty = {'beginner', 'intermediate', 'advanced'}.contains(spot.difficulty)
        ? spot.difficulty
        : 'beginner';
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit spot', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  readOnly: true,
                  onTap: () async {
                    final picked = await _pickSpotPosition(selectedPosition);
                    if (picked == null) return;
                    selectedPosition = picked;
                    final updatedAddress = await _getAddressFromCoordinates(selectedPosition);
                    if (!mounted) return;
                    setDialogState(() {
                      pinWasUpdated = true;
                      addressController.text = updatedAddress;
                    });
                  },
                  decoration: const InputDecoration(labelText: 'Address (tap to edit pin)'),
                ),
                if (pinWasUpdated)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pin updated for this spot.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF00A86B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Types',
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (({..._allKnownTypes(), ...selectedTypes}.toList()..sort()).map(
                    (type) => FilterChip(
                      label: Text(type),
                      selected: selectedTypes.contains(type),
                      onSelected: (enabled) {
                        setDialogState(() {
                          if (enabled) {
                            selectedTypes.add(type);
                          } else {
                            selectedTypes.remove(type);
                          }
                        });
                      },
                    ),
                  )).toList(),
                ),
                TextField(
                  controller: customTypeController,
                  maxLength: 50,
                  decoration: const InputDecoration(labelText: 'Add custom type'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      final custom = customTypeController.text.trim();
                      if (custom.isEmpty || custom.length > 50) return;
                      setDialogState(() {
                        selectedTypes.add(custom);
                        customTypeController.clear();
                      });
                    },
                    child: const Text('Add type'),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedDifficulty,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: const [
                    DropdownMenuItem(value: 'beginner', child: Text('Beginner')),
                    DropdownMenuItem(value: 'intermediate', child: Text('Intermediate')),
                    DropdownMenuItem(value: 'advanced', child: Text('Advanced')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() {
                      selectedDifficulty = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                if (photos.isNotEmpty)
                  SizedBox(
                    height: 95,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final photo = photos[index];
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () => _openPhotoViewer(photo.url),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _spotApi.resolvePhotoUrl(photo.url),
                                  width: 110,
                                  height: 95,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () async {
                                  try {
                                    final updated = await _spotApi.deletePhoto(
                                      spotId: spot.id,
                                      photoId: photo.id,
                                    );
                                    setDialogState(() {
                                      photos
                                        ..clear()
                                        ..addAll(updated.photos);
                                    });
                                    await _loadSkateSpots();
                                  } catch (_) {}
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  color: Colors.black54,
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    final XFile? picked = await _imagePicker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 85,
                    );
                    if (picked == null) return;
                    final updated = await _spotApi.uploadPhotos(
                      spotId: spot.id,
                      files: [File(picked.path)],
                    );
                    setDialogState(() {
                      photos
                        ..clear()
                        ..addAll(updated.photos);
                    });
                    await _loadSkateSpots();
                  },
                  icon: const Icon(Icons.add_photo_alternate),
                  label: const Text('Add photo'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) return;
                      setDialogState(() {
                        isSaving = true;
                      });
                      try {
                        await _spotApi.updateSpot(
                          spotId: spot.id,
                          name: nameController.text.trim(),
                          type: _encodeTypes(selectedTypes),
                          address: addressController.text.trim(),
                          latitude: selectedPosition.latitude,
                          longitude: selectedPosition.longitude,
                          description: descriptionController.text.trim().isEmpty
                              ? null
                              : descriptionController.text.trim(),
                          difficulty: selectedDifficulty,
                        );
                        await _loadSkateSpots();
                        if (!mounted) return;
                        Navigator.pop(dialogContext);
                      } catch (error) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Could not update spot: $error'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        setDialogState(() {
                          isSaving = false;
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleListFullscreen() {
    setState(() {
      _isListFullscreen = !_isListFullscreen;
      if (!_isListFullscreen) {
        _showFilterPanel = false;
      }
    });
  }

  @override
  void dispose() {
    _spotApi.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleSpots = _visibleSpots;
    return PopScope(
      canPop: !_isListFullscreen,
      onPopInvoked: (didPop) {
        if (!didPop && _isListFullscreen) {
          setState(() {
            _isListFullscreen = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              // Map area
              Positioned(
                top: 130,
                left: 0,
                right: 0,
                bottom: _isListFullscreen ? 0 : 200,
                child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _currentLocation != null
                        ? LatLng(
                            _currentLocation!.latitude!,
                            _currentLocation!.longitude!,
                          )
                        : const LatLng(39.4699, -0.3763),
                    initialZoom: 13.0,
                    minZoom: 5.0,
                    maxZoom: 18.0,
                    onTap: (tapPosition, point) {
                      // Add pin at tapped location
                      setState(() {
                        _temporaryPinPosition = point;
                      });
                      // Show dialog to add spot
                      _showAddSpotDialog(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.flatground_app',
                    ),
                    MarkerLayer(
                      markers: [
                        // Current location marker
                        if (_currentLocation != null)
                          Marker(
                            point: LatLng(
                              _currentLocation!.latitude!,
                              _currentLocation!.longitude!,
                            ),
                            width: 36,
                            height: 36,
                            rotate: true,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF00A86B),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.my_location,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        // Temporary pin marker (when user taps to add)
                        if (_temporaryPinPosition != null)
                          Marker(
                            point: _temporaryPinPosition!,
                            width: 40,
                            height: 40,
                            rotate: true,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFC7C1E4),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.add_location,
                                color: Color(0xFF2F00FF),
                                size: 24,
                              ),
                            ),
                          ),
                        // Skate spot markers
                        ...visibleSpots.map((spot) => Marker(
                              point: LatLng(spot.latitude, spot.longitude),
                              width: 40,
                              height: 40,
                              rotate: true,
                              child: GestureDetector(
                                onTap: () => _showSpotDetails(spot),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC7C1E4),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.place,
                                    color: Color(0xFF2F00FF),
                                    size: 24,
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Add spot button
            Positioned(
              top: 136,
              right: 8,
              child: FloatingActionButton(
                onPressed: () {
                  final center = _mapController.camera.center;
                  _showAddSpotDialog(center);
                },
                backgroundColor: const Color(0xFF2F00FF),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
            Positioned(
              right: 8,
              bottom: _isListFullscreen ? 12 : 212,
              child: FloatingActionButton.small(
                onPressed: _goToCurrentLocation,
                backgroundColor: const Color(0xFF2F00FF),
                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),

              // Skate spots list
              if (!_isListFullscreen)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 180,
                    margin: const EdgeInsets.symmetric(horizontal: 26, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: const Color(0xFFC7C1E4),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with title and expand button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Skate spots near you',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: const Color(0xFFC7C1E4),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: _toggleListFullscreen,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.fullscreen,
                                  color: Color(0xFF2F00FF),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_isLoadingSpots)
                          const Expanded(
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF2F00FF),
                              ),
                            ),
                          )
                        else if (_spotsError != null)
                          Expanded(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 22),
                                child: Text(
                                  _spotsError!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: const Color(0xFF180081).withOpacity(0.6),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else if (visibleSpots.isEmpty)
                          Expanded(
                            child: Center(
                              child: Text(
                                _selectedTypeFilters.isEmpty
                                    ? 'No skate spots yet.'
                                    : 'No spots for selected type.',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: const Color(0xFF180081).withOpacity(0.6),
                                ),
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: RefreshIndicator(
                              onRefresh: _loadSkateSpots,
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: visibleSpots.length,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.only(
                                  left: 22,
                                  right: 22,
                                  bottom: 8,
                                ),
                                itemBuilder: (context, index) {
                                  final spot = visibleSpots[index];
                                  return GestureDetector(
                                    onTap: () {
                                      _mapController.move(
                                        LatLng(spot.latitude, spot.longitude),
                                        15.0,
                                      );
                                      _showSpotDetails(spot);
                                    },
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        bottom: index < visibleSpots.length - 1 ? 12 : 0,
                                      ),
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC7C1E4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // Spot name and type
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    spot.name,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color: const Color(0xFF2F00FF),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    spot.type,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: const Color(0xFF2F00FF)
                                                          .withOpacity(0.7),
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Address
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                spot.address,
                                                textAlign: TextAlign.right,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: const Color(0xFF180081)
                                                      .withOpacity(0.44),
                                                  fontWeight: FontWeight.w300,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Fullscreen list overlay
              if (_isListFullscreen)
                Positioned(
                  top: 130,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        // Header with title and close button
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  'Skate spots near you',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    color: const Color(0xFFC7C1E4),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: _toggleListFullscreen,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.fullscreen_exit,
                                  color: Color(0xFF2F00FF),
                                  size: 24,
                                ),
                              ),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _showFilterPanel = !_showFilterPanel;
                                  });
                                },
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: Icon(
                                  Icons.filter_alt,
                                  color: _showFilterPanel
                                      ? const Color(0xFF2F00FF)
                                      : const Color(0xFFC7C1E4),
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showFilterPanel)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _selectedTypeFilters.isEmpty
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedTypeFilters.clear();
                                        });
                                      },
                                child: const Text('Clear filters'),
                              ),
                            ),
                          ),
                        if (_showFilterPanel)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _allKnownTypes()
                                  .map(
                                    (type) => FilterChip(
                                      label: Text(type),
                                      selected: _selectedTypeFilters.contains(type),
                                      onSelected: (enabled) {
                                        setState(() {
                                          if (enabled) {
                                            _selectedTypeFilters.add(type);
                                          } else {
                                            _selectedTypeFilters.remove(type);
                                          }
                                        });
                                      },
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        if (_isLoadingSpots)
                          const Expanded(
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF2F00FF),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: RefreshIndicator(
                              onRefresh: _loadSkateSpots,
                              child: ListView.builder(
                                itemCount: visibleSpots.length,
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 26),
                                itemBuilder: (context, index) {
                                  final spot = visibleSpots[index];
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isListFullscreen = false;
                                      });
                                      _mapController.move(
                                        LatLng(spot.latitude, spot.longitude),
                                        15.0,
                                      );
                                      _showSpotDetails(spot);
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      height: 58,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFC7C1E4),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            // Spot name and type
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    spot.name,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 14,
                                                      color: const Color(0xFF2F00FF),
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    spot.type,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: const Color(0xFF2F00FF)
                                                          .withOpacity(0.7),
                                                      fontWeight: FontWeight.w400,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            // Address
                                            Expanded(
                                              flex: 3,
                                              child: Text(
                                                spot.address,
                                                textAlign: TextAlign.right,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: const Color(0xFF180081)
                                                      .withOpacity(0.44),
                                                  fontWeight: FontWeight.w300,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
