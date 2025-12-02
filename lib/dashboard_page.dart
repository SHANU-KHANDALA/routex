import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  // Map controller
  final Completer<GoogleMapController> _mapController = Completer();

  // Sidebar toggle
  bool _showSidebar = false;

  // Demo stops (matching your earlier data)
  final List<LatLng> _stopLocations = [
    const LatLng(12.9716, 77.5946), // Central Station (example)
    const LatLng(12.9728, 77.5958), // Park Avenue (next)
    const LatLng(12.9740, 77.5971), // School Campus
  ];

  final List<Map<String, dynamic>> _stops = [
    {
      "id": "1",
      "name": "Central Station",
      "scheduledTime": "7:30 AM",
      "eta": 15,
      "distance": 3.2,
    },
    {
      "id": "2",
      "name": "Park Avenue",
      "scheduledTime": "7:35 AM",
      "eta": 8,
      "distance": 1.8,
    },
    {
      "id": "3",
      "name": "School Campus",
      "scheduledTime": "7:40 AM",
      "eta": 13,
      "distance": 2.5,
    },
  ];

  // Markers & polylines
  final Map<MarkerId, Marker> _markers = {};
  final Map<PolylineId, Polyline> _polylines = {};

  // Demo bus location (moving)
  LatLng _busLocation = const LatLng(12.9719, 77.5950);

  // Animation timer for demo bus movement
  Timer? _busTimer;
  int _busStep = 0;

  // initial camera position (center)
  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(12.9716, 77.5946),
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _initMarkersAndPolylines();
    _startBusSimulation();
  }

  @override
  void dispose() {
    _busTimer?.cancel();
    super.dispose();
  }

  // Initialize demo markers & a sample polyline between bus and next stop
  void _initMarkersAndPolylines() {
    // Stops markers
    for (var i = 0; i < _stopLocations.length; i++) {
      final id = MarkerId('stop_$i');
      final stop = _stops[i];
      final marker = Marker(
        markerId: id,
        position: _stopLocations[i],
        infoWindow: InfoWindow(
          title: stop['name'],
          snippet: stop['scheduledTime'],
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
      _markers[id] = marker;
    }

    // Bus marker (dynamic, add first time)
    final busId = const MarkerId('bus_marker');
    _markers[busId] = Marker(
      markerId: busId,
      position: _busLocation,
      infoWindow: const InfoWindow(title: "Bus #247"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    );

    // Initial polyline demo (between bus and next stop)
    final polyId = const PolylineId('route_poly');
    _polylines[polyId] = Polyline(
      polylineId: polyId,
      width: 4,
      color: Colors.blueAccent,
      points: [_busLocation, _stopLocations[1]],
    );
  }

  // Demo bus movement: moves bus slightly along a small path
  void _startBusSimulation() {
    const duration = Duration(seconds: 2);
    _busTimer = Timer.periodic(duration, (_) async {
      // Move bus in a small loop between points
      _busStep = (_busStep + 1) % _stopLocations.length;
      final target = _stopLocations[_busStep];
      // simple lerp for demo
      _busLocation = LatLng(
        (_busLocation.latitude + target.latitude) / 2,
        (_busLocation.longitude + target.longitude) / 2,
      );

      _updateBusMarker();
      _updatePolylineToNextStop();

      // optionally animate camera to bus (comment out if undesired)
      final controller = await _mapController.future;
      controller.animateCamera(CameraUpdate.newLatLng(_busLocation));
      setState(() {});
    });
  }

  // Replace bus marker with updated position
  void _updateBusMarker() {
    final id = const MarkerId('bus_marker');
    final marker = Marker(
      markerId: id,
      position: _busLocation,
      infoWindow: const InfoWindow(title: "Bus #247"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    );
    setState(() {
      _markers[id] = marker;
    });
  }

  // Update polyline between bus and next stop (next stop index = 1 in demo)
  void _updatePolylineToNextStop() {
    final polyId = const PolylineId('route_poly');
    final nextStop = _stopLocations[1];
    final polyline = Polyline(
      polylineId: polyId,
      width: 4,
      color: Colors.blueAccent,
      points: [_busLocation, nextStop],
    );
    setState(() {
      _polylines[polyId] = polyline;
    });
  }

  // Ask for location permission and get current device location
  Future<Position?> _determinePosition() async {
    // request permission via permission_handler for web-friendly approach
    final status = await Permission.location.request();
    if (status != PermissionStatus.granted) {
      // permission denied
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
      }
      return null;
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
      return null;
    }
  }

  // Move camera to device location
  Future<void> _goToMyLocation() async {
    final pos = await _determinePosition();
    if (pos == null) return;
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
    );
  }

  // Toggle sidebar
  void _toggleSidebar() {
    setState(() {
      _showSidebar = !_showSidebar;
    });
  }

  // Build the left sidebar content (scrollable)
  Widget _buildSidebarContent() {
    return SizedBox(
      width: 320,
      child: SingleChildScrollView(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bus #247",
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          "Route: Campus Express",
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ETA card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Next Stop",
                            style: GoogleFonts.montserrat(
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Park Avenue",
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.timer, color: Colors.blue),
                          const SizedBox(height: 4),
                          Text(
                            "8 min",
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Stops list
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "Route Stops",
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Column(
                  children: _stops.map((s) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s['name'],
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${s['scheduledTime']} • ${s['eta']} min",
                                  style: GoogleFonts.montserrat(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${s['distance']} km",
                            style: GoogleFonts.montserrat(),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 24),

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Example: call driver - hook your phone dialer here
                        },
                        icon: const Icon(Icons.phone),
                        label: const Text("Call Driver"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Report issue action
                        },
                        icon: const Icon(Icons.report_problem),
                        label: const Text("Report Issue"),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Main build
  @override
  Widget build(BuildContext context) {
    final map = GoogleMap(
      mapType: MapType.normal,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      initialCameraPosition: _initialCamera,
      markers: Set<Marker>.of(_markers.values),
      polylines: Set<Polyline>.of(_polylines.values),
      onMapCreated: (GoogleMapController controller) {
        if (!_mapController.isCompleted) _mapController.complete(controller);
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('RouteX Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // assume sign out handled elsewhere
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full-screen map
          Positioned.fill(child: map),

          // Search bar + small button under it to toggle sidebar
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 6),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.search, color: Colors.black54),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: 'Search address or stop',
                                ),
                                onSubmitted: (q) {
                                  // implement search later
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Small button that toggles the sidebar (and also the "open page" action)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: _toggleSidebar,
                      child: const Icon(Icons.menu),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Animated sidebar sliding from left
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            left: _showSidebar ? 0 : -340, // fully hidden when -340
            width: 320,
            child: SafeArea(
              child: Material(elevation: 12, child: _buildSidebarContent()),
            ),
          ),

          // Bottom floating bus status box (fixed above map)
          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 12)],
              ),
              child: Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.shade400,
                          Colors.deepOrange.shade400,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.directions_bus, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Bus #247 • On Route",
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              "Speed: 45 km/h",
                              style: GoogleFonts.montserrat(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Distance: 1.8 km",
                              style: GoogleFonts.montserrat(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "ETA: 8 min",
                              style: GoogleFonts.montserrat(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // small button to center map on bus location
                      _centerMapOnBus();
                    },
                    child: const Icon(Icons.location_searching),
                  ),
                ],
              ),
            ),
          ),

          // My location Floating action button (small)
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              mini: true,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }

  // Center map on bus marker
  Future<void> _centerMapOnBus() async {
    final controller = await _mapController.future;
    controller.animateCamera(CameraUpdate.newLatLngZoom(_busLocation, 16));
  }
}
