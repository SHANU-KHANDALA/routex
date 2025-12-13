import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart'; // 1. Added Firebase Auth Import
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- CONFIGURATION ---
  // ---TODO: Paste your API Key here
  static const String _googleApiKey = "PASTE_YOUR_KEY_HERE";

  final Completer<GoogleMapController> _mapController = Completer();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Sidebar & Camera State
  bool _showLeftSidebar = false;
  bool _isAutoCamera = true;

  // --- EDIT YOUR STOPS HERE (EVERYTHING ELSE WILL SYNC AUTOMATICALLY) ---
  final List<LatLng> _stopLocations = [
    const LatLng(22.818023, 75.943507),
    const LatLng(22.817724, 75.938138),
    const LatLng(22.754549, 75.934626),
    const LatLng(22.754528, 75.930608),
    const LatLng(22.745208, 75.929004),
    const LatLng(22.749603, 75.903561),
    const LatLng(22.750783, 75.895587),
    const LatLng(22.755260, 75.878421),
  ];

  final List<Map<String, dynamic>> _stops = [
    {"id": "1", "name": "Acropolis", "time": "6:10 AM"},
    {"id": "1", "name": "bypaas Road", "time": "6:05 AM"},
    {"id": "1", "name": "Hare Krishna Vihar", "time": "6:30 AM"},
    {"id": "1", "name": "Hare Krishna Vihar", "time": "6:30 AM"},
    {"id": "1", "name": "Knight Square", "time": "6:30 AM"},
    {"id": "2", "name": "Radisson Blu", "time": "6:45 AM"},
    {"id": "2", "name": "vijay nagr", "time": "6:55 AM"},
    {"id": "3", "name": "Bapat Square", "time": "7:15 AM"},
  ];
  // ---------------------------------------------------------------------

  // Dynamic Data
  String _currentDistance = "0 km";
  String _currentDuration = "0 min";
  String _nextStopName = "Loading...";
  String _debugStatus = "";

  // Map Elements
  final Map<MarkerId, Marker> _markers = {};
  final Map<PolylineId, Polyline> _polylines = {};

  // Simulation State
  late LatLng _busLocation;
  late CameraPosition _initialCamera;

  Timer? _busTimer;
  int _currentRouteIndex = 0;
  double _fractionTraveled = 0.0;

  @override
  void initState() {
    super.initState();

    // --- SMART SETUP: Auto-set start to the first stop ---
    if (_stopLocations.isNotEmpty) {
      _busLocation = _stopLocations[0];
      _initialCamera = CameraPosition(target: _stopLocations[0], zoom: 14.5);
    } else {
      _busLocation = const LatLng(0, 0);
      _initialCamera = const CameraPosition(target: LatLng(0, 0), zoom: 1);
    }

    _initStaticMarkers();
    _updateBusMarker();

    if (_stops.length > 1) {
      _nextStopName = _stops[1]['name'];
      _getDirections(_stopLocations[0], _stopLocations[1]);
    }

    _startBusSimulation();
  }

  @override
  void dispose() {
    _busTimer?.cancel();
    super.dispose();
  }

  // --- API LOGIC ---
  Future<void> _getDirections(LatLng start, LatLng dest) async {
    if (_googleApiKey.contains("AIzaSyA2Uh9gd06RbRVk3sOC2UrIir5Lp1SFWgw")) {
      setState(() {
        _debugStatus = "PASTE API KEY";
        _updatePolylineStraight(start, dest);
      });
      return;
    }

    String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${dest.latitude},${dest.longitude}&mode=driving&key=$_googleApiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final json = jsonDecode(response.body);

      if (json['status'] == 'OK') {
        final pointsString = json['routes'][0]['overview_polyline']['points'];
        final PolylinePoints polylinePoints = PolylinePoints();
        List<PointLatLng> result = polylinePoints.decodePolyline(pointsString);

        List<LatLng> polylineCoordinates = result
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        final leg = json['routes'][0]['legs'][0];

        setState(() {
          _debugStatus = "";
          _currentDistance = leg['distance']['text'];
          _currentDuration = leg['duration']['text'];

          final polyId = const PolylineId('route_poly');
          _polylines[polyId] = Polyline(
            polylineId: polyId,
            width: 5,
            color: Colors.blueAccent,
            points: polylineCoordinates,
          );
        });
      } else {
        setState(() {
          _debugStatus = "API ERROR: ${json['status']}";
          _updatePolylineStraight(start, dest);
        });
      }
    } catch (e) {
      setState(() => _debugStatus = "Network Error");
    }
  }

  void _updatePolylineStraight(LatLng start, LatLng dest) {
    final polyId = const PolylineId('route_poly');
    setState(() {
      _polylines[polyId] = Polyline(
        polylineId: polyId,
        width: 4,
        color: Colors.grey,
        points: [start, dest],
      );
    });
  }

  // --- SIMULATION ---
  void _startBusSimulation() {
    const fps = Duration(milliseconds: 500);
    _busTimer = Timer.periodic(fps, (_) async {
      if (_currentRouteIndex >= _stopLocations.length - 1) {
        _currentRouteIndex = 0;
        _fractionTraveled = 0.0;
        _getDirections(_stopLocations[0], _stopLocations[1]);
        setState(() => _nextStopName = _stops[1]['name']);
      }

      final start = _stopLocations[_currentRouteIndex];
      final end = _stopLocations[_currentRouteIndex + 1];

      _fractionTraveled += 0.02;

      if (_fractionTraveled >= 1.0) {
        _fractionTraveled = 0.0;
        _currentRouteIndex++;

        if (_currentRouteIndex < _stopLocations.length - 1) {
          final nextIndex = _currentRouteIndex + 1;
          _getDirections(
            _stopLocations[_currentRouteIndex],
            _stopLocations[nextIndex],
          );
          setState(() => _nextStopName = _stops[nextIndex]['name']);
        }
      }

      final lat =
          start.latitude + (end.latitude - start.latitude) * _fractionTraveled;
      final lng =
          start.longitude +
          (end.longitude - start.longitude) * _fractionTraveled;
      _busLocation = LatLng(lat, lng);

      _updateBusMarker();

      if (_isAutoCamera && _mapController.isCompleted) {
        final controller = await _mapController.future;
        controller.animateCamera(CameraUpdate.newLatLng(_busLocation));
      }
    });
  }

  void _initStaticMarkers() {
    for (var i = 0; i < _stopLocations.length; i++) {
      final id = MarkerId('stop_$i');
      _markers[id] = Marker(
        markerId: id,
        position: _stopLocations[i],
        infoWindow: InfoWindow(title: _stops[i]['name']),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    }
  }

  void _updateBusMarker() {
    setState(() {
      final busId = const MarkerId('bus_marker');
      _markers[busId] = Marker(
        markerId: busId,
        position: _busLocation,
        infoWindow: const InfoWindow(title: "Bus #247"),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        zIndex: 2,
      );
    });
  }

  Future<void> _goToMyLocation() async {
    final status = await Permission.location.request();
    if (status != PermissionStatus.granted) return;
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!_mapController.isCompleted) return;

      setState(() => _isAutoCamera = false);

      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 16),
      );
    } catch (e) {
      /* ignore */
    }
  }

  // --- UI BUILDERS ---

  Widget _buildRightProfileSidebar() {
    // 2. Fetch User Data from Firebase
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName ?? "User";
    final email = user?.email ?? "No Email";
    // Get first letter for avatar, defaulting to "U"
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : "U";

    return Drawer(
      width: 280,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1E3A8A)),
            accountName: Text(
              displayName, // Display actual name
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(email), // Display actual email
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                initials,
                style: const TextStyle(fontSize: 20, color: Color(0xFF1E3A8A)),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Log Out", style: TextStyle(color: Colors.red)),
            onTap: () async {
              // 3. Close the drawer first
              Navigator.of(context).pop();

              // 4. Actual Firebase Logout
              // The AuthGate in your main.dart will detect this and switch to Login Page
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSidebarContent() {
    return SizedBox(
      width: 320,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A8A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_bus,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Bus #247",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        "Campus Express",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Current Leg:",
                      style: TextStyle(color: Colors.black87),
                    ),
                    Text(
                      _currentDistance,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 30),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _stops.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const Icon(Icons.place, color: Colors.redAccent),
                    title: Text(_stops[index]['name']),
                    subtitle: Text(_stops[index]['time']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _buildRightProfileSidebar(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('RouteX'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () => _scaffoldKey.currentState!.openEndDrawer(),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                child: const Icon(Icons.person, color: Color(0xFF1E3A8A)),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) {
                setState(() => _isAutoCamera = false);
              },
              child: GoogleMap(
                mapType: MapType.normal,
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                initialCameraPosition: _initialCamera,
                markers: Set<Marker>.of(_markers.values),
                polylines: Set<Polyline>.of(_polylines.values),
                onMapCreated: (c) {
                  if (!_mapController.isCompleted) _mapController.complete(c);
                },
              ),
            ),
          ),

          if (_debugStatus.isNotEmpty)
            Positioned(
              top: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  color: Colors.redAccent,
                  child: Text(
                    _debugStatus,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: "Search Stop...",
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () =>
                      setState(() => _showLeftSidebar = !_showLeftSidebar),
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4),
                      ],
                    ),
                    child: const Icon(Icons.menu),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.orangeAccent,
                    ),
                    child: const Icon(
                      Icons.directions_bus,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "NEXT STOP",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _nextStopName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF1E3A8A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.near_me,
                              size: 14,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentDistance,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  FloatingActionButton.small(
                    heroTag: "recenter_btn",
                    backgroundColor: _isAutoCamera
                        ? Colors.blue
                        : Colors.grey.shade400,
                    child: const Icon(Icons.center_focus_strong),
                    onPressed: () {
                      setState(() => _isAutoCamera = true);
                      _mapController.future.then(
                        (c) => c.animateCamera(
                          CameraUpdate.newLatLng(_busLocation),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: "mylocation_btn",
              mini: true,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          if (_showLeftSidebar)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showLeftSidebar = false;
                  });
                },
                child: Container(color: Colors.black12),
              ),
            ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: _showLeftSidebar ? 0 : -320,
            top: 0,
            bottom: 0,
            width: 320,
            child: Material(elevation: 8, child: _buildLeftSidebarContent()),
          ),
        ],
      ),
    );
  }
}
