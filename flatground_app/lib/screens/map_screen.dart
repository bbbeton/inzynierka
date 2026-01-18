import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';

class SkateSpot {
  final String id;
  final String name;
  final String type;
  final String address;
  final LatLng position;
  final String? description;
  final List<String>? photos;

  SkateSpot({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.position,
    this.description,
    this.photos,
  });
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  LocationData? _currentLocation;
  final Location _locationService = Location();
  List<SkateSpot> _skateSpots = [];
  LatLng? _temporaryPinPosition;
  bool _isListFullscreen = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadSkateSpots();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await _locationService.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _locationService.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await _locationService.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _locationService.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    _currentLocation = await _locationService.getLocation();
    if (_currentLocation != null) {
      _mapController.move(
        LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
        13.0,
      );
    }
  }

  void _loadSkateSpots() {
    // Load default spots or from storage
    setState(() {
      _skateSpots = [
        SkateSpot(
          id: '1',
          name: 'Skateplaza',
          type: 'Plaza',
          address: 'C/ del Pla de la Sadia',
          position: LatLng(39.4699, -0.3763),
        ),
        SkateSpot(
          id: '2',
          name: 'MuVIM',
          type: 'Street',
          address: 'MuVIM museo',
          position: LatLng(39.4800, -0.3770),
        ),
        SkateSpot(
          id: '3',
          name: 'Parque de Beteró',
          type: 'Bowl',
          address: 'Campillo de Altobuey',
          position: LatLng(39.4700, -0.3750),
        ),
      ];
    });
  }

  void _showAddSpotDialog(LatLng position) {
    final nameController = TextEditingController();
    final typeController = TextEditingController();
    final addressController = TextEditingController();
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              TextField(
                controller: typeController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Type (e.g., Plaza, Street, Bowl)',
                  labelStyle: GoogleFonts.poppins(fontSize: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                style: GoogleFonts.poppins(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Address',
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
            onPressed: () {
              if (nameController.text.isNotEmpty &&
                  typeController.text.isNotEmpty &&
                  addressController.text.isNotEmpty) {
                final newSpot = SkateSpot(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text,
                  type: typeController.text,
                  address: addressController.text,
                  position: position,
                  description: descriptionController.text.isEmpty
                      ? null
                      : descriptionController.text,
                );
                setState(() {
                  _skateSpots.add(newSpot);
                  _temporaryPinPosition = null; // Clear temporary pin
                });
                Navigator.pop(context);
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
    );
  }

  void _showSpotDetails(SkateSpot spot) {
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
            Text(
              spot.name,
              style: GoogleFonts.poppins(
                fontSize: 24,
                color: const Color(0xFF2F00FF),
                fontWeight: FontWeight.w600,
              ),
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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _toggleListFullscreen() {
    setState(() {
      _isListFullscreen = !_isListFullscreen;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                            width: 30,
                            height: 30,
                            child: const Icon(
                              Icons.my_location,
                              color: Color(0xFF2F00FF),
                              size: 30,
                            ),
                          ),
                        // Temporary pin marker (when user taps to add)
                        if (_temporaryPinPosition != null)
                          Marker(
                            point: _temporaryPinPosition!,
                            width: 40,
                            height: 40,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.add_location,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        // Skate spot markers
                        ..._skateSpots.map((spot) => Marker(
                              point: spot.position,
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _showSpotDetails(spot),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2F00FF),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.place,
                                    color: Colors.white,
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
              top: 200,
              right: 26,
              child: FloatingActionButton(
                onPressed: () {
                  final center = _mapController.camera.center;
                  _showAddSpotDialog(center);
                },
                backgroundColor: const Color(0xFF2F00FF),
                child: const Icon(Icons.add, color: Colors.white),
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
                          padding: const EdgeInsets.all(22),
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
                        Expanded(
                          child: ListView.builder(
                            itemCount: _skateSpots.length,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 0),
                            itemBuilder: (context, index) {
                              final spot = _skateSpots[index];
                              return GestureDetector(
                                onTap: () {
                                  _mapController.move(spot.position, 15.0);
                                  _showSpotDetails(spot);
                                },
                                child: Container(
                                  margin: EdgeInsets.only(
                                    bottom: index < _skateSpots.length - 1 ? 12 : 0,
                                  ),
                                  height: 55,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC7C1E4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _skateSpots.length,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 26),
                            itemBuilder: (context, index) {
                              final spot = _skateSpots[index];
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isListFullscreen = false;
                                  });
                                  _mapController.move(spot.position, 15.0);
                                  _showSpotDetails(spot);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  height: 59,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC7C1E4),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
