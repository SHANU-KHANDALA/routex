import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- CONFIGURATION ---
  // TODO: Paste your actual API Key here
  static const String _googleApiKey = "AIzaSyA2Uh9gd06RbRVk3sOC2UrIir5Lp1SFWgw";

  // EMAIL CONFIGURATION
  final String _senderEmail = "shanukhandala4@gmail.com";
  final String _senderPassword = "mttp iwyk kysc ngeg";

  final Completer<GoogleMapController> _mapController = Completer();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State Variables
  bool _showLeftSidebar = false;
  bool _isAutoCamera = true;
  String? _userSelectedStopName;

  // Data from Firestore
  List<Map<String, dynamic>> _stops = [];
  List<LatLng> _stopLocations = [];
  String _busName = "Loading...";
  String _driverName = "Loading...";
  bool _isLoading = true;

  // Search State
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredStops = [];
  bool _isSearching = false;

  // Dynamic Data
  String _currentDistance = "--";
  String _nextStopName = "Starting...";
  String _debugStatus = "";

  // Map Elements
  final Map<MarkerId, Marker> _markers = {};
  final Map<PolylineId, Polyline> _polylines = {};

  // Simulation State
  LatLng _busLocation = const LatLng(0, 0);
  CameraPosition _initialCamera = const CameraPosition(
    target: LatLng(22.7196, 75.8577),
    zoom: 12,
  );
  Timer? _busTimer;
  int _currentRouteIndex = 0;
  double _fractionTraveled = 0.0;
  bool _emailSentForCurrentStop = false; // Prevents spamming emails

  @override
  void initState() {
    super.initState();
    _fetchBusData();

    _searchController.addListener(() {
      final query = _searchController.text.toLowerCase();
      setState(() {
        if (query.isEmpty) {
          _isSearching = false;
          _filteredStops = _stops;
        } else {
          _isSearching = true;
          _filteredStops = _stops
              .where(
                (s) =>
                    s['name'].toString().toLowerCase().contains(query) ||
                    _busName.toLowerCase().contains(query),
              )
              .toList();
        }
      });
    });
  }

  @override
  void dispose() {
    _busTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // --- 1. EMAIL LOGIC (Replaces Python Code) ---
  Future<void> _sendEmailAlert(String stopName) async {
    // Get the user who is logged into the app
    final user = FirebaseAuth.instance.currentUser;
    final recipientEmail = user?.email;

    if (recipientEmail == null) {
      print("No user email found to send alert.");
      return;
    }

    // Configure the Gmail Server (Like smtplib.SMTP)
    final smtpServer = gmail(_senderEmail, _senderPassword);

    // Create the message
    final message = Message()
      ..from = Address(_senderEmail, 'RouteX Bus Tracker')
      ..recipients.add(recipientEmail)
      ..subject = 'Bus Arriving at $stopName'
      ..text =
          'Hello,\n\nYour bus ($_busName) is arriving at $stopName shortly.\n\nPlease get ready!\n\n- Team RouteX';

    try {
      final sendReport = await send(message, smtpServer);
      print('Message sent: ' + sendReport.toString());

      // Show confirmation on screen
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Email sent to $recipientEmail"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Message not sent. \n' + e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to send email alert"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // --- 2. FIRESTORE ---
  Future<void> _fetchBusData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('buses')
          .doc('bus_247')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        setState(() {
          _busName = data['busNumber'] ?? "Bus";
          _driverName = data['driverName'] ?? "Driver";

          List<dynamic> rawStops = data['stops'] ?? [];
          _stops = rawStops.map((e) => e as Map<String, dynamic>).toList();
          _filteredStops = _stops;

          _stopLocations = _stops
              .map((s) => LatLng(s['lat'], s['lng']))
              .toList();

          if (_stopLocations.isNotEmpty) {
            _busLocation = _stopLocations[0];
            _initialCamera = CameraPosition(
              target: _stopLocations[0],
              zoom: 14.5,
            );
            _nextStopName = _stops.length > 1 ? _stops[1]['name'] : "End";
          }
          _isLoading = false;
        });

        _initStaticMarkers();
        _updateBusMarker();
        if (_stops.length > 1) {
          _getDirections(_stopLocations[0], _stopLocations[1]);
        }
        _startBusSimulation();
      } else {
        setState(() {
          _debugStatus = "Bus 247 not found";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _debugStatus = "Connection Error";
        _isLoading = false;
      });
    }
  }

  // --- 3. API & SIMULATION ---
  Future<void> _getDirections(LatLng start, LatLng dest) async {
    if (_googleApiKey.contains("PASTE")) return;

    String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${start.latitude},${start.longitude}&destination=${dest.latitude},${dest.longitude}&mode=driving&key=$_googleApiKey";

    try {
      final response = await http.get(Uri.parse(url));
      final json = jsonDecode(response.body);

      if (json['status'] == 'OK') {
        final pointsString = json['routes'][0]['overview_polyline']['points'];
        final leg = json['routes'][0]['legs'][0];
        List<LatLng> polylineCoordinates = _decodePolyline(pointsString);

        setState(() {
          _currentDistance = leg['distance']['text'];
          final polyId = const PolylineId('route_poly');
          _polylines[polyId] = Polyline(
            polylineId: polyId,
            width: 5,
            color: const Color(0xFF4285F4),
            points: polylineCoordinates,
          );
        });
      }
    } catch (e) {
      /* silent fail */
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _startBusSimulation() {
    if (_stopLocations.isEmpty) return;
    const fps = Duration(milliseconds: 500);
    _busTimer = Timer.periodic(fps, (_) async {
      if (_currentRouteIndex >= _stopLocations.length - 1) {
        _currentRouteIndex = 0;
        _fractionTraveled = 0.0;
        if (_stops.isNotEmpty)
          setState(() => _nextStopName = _stops[1]['name']);
      }

      final start = _stopLocations[_currentRouteIndex];
      final end = _stopLocations[_currentRouteIndex + 1];

      _fractionTraveled += 0.02;

      if (_fractionTraveled >= 1.0) {
        _fractionTraveled = 0.0;
        _currentRouteIndex++;
        _emailSentForCurrentStop = false; // Reset email flag for new stop

        if (_currentRouteIndex < _stopLocations.length - 1) {
          final nextIndex = _currentRouteIndex + 1;
          final nextStopName = _stops[nextIndex]['name'];

          setState(() => _nextStopName = nextStopName);
          _getDirections(
            _stopLocations[_currentRouteIndex],
            _stopLocations[nextIndex],
          );

          // --- EMAIL TRIGGER LOGIC ---
          if (_userSelectedStopName != null &&
              nextStopName == _userSelectedStopName &&
              !_emailSentForCurrentStop) {
            _emailSentForCurrentStop =
                true; // Mark as sent so we don't send 100 emails
            print("TRIGGERING EMAIL TO USER...");
            await _sendEmailAlert(nextStopName);
          }
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
        final c = await _mapController.future;
        c.animateCamera(CameraUpdate.newLatLng(_busLocation));
      }
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

  // --- UI HELPERS ---
  void _initStaticMarkers() {
    _markers.clear();
    for (var i = 0; i < _stopLocations.length; i++) {
      final name = _stops[i]['name'];
      final isSelected = name == _userSelectedStopName;
      final id = MarkerId('stop_$i');
      _markers[id] = Marker(
        markerId: id,
        position: _stopLocations[i],
        infoWindow: InfoWindow(title: name, snippet: _stops[i]['time']),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueAzure,
        ),
      );
    }
    setState(() {});
  }

  void _updateBusMarker() {
    final busId = const MarkerId('bus_marker');
    _markers[busId] = Marker(
      markerId: busId,
      position: _busLocation,
      infoWindow: InfoWindow(title: _busName),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      zIndex: 2,
    );
    setState(() {});
  }

  void _handleStopSelection(String stopName) {
    setState(() {
      _userSelectedStopName = stopName;
      _showLeftSidebar = false;
      _searchController.clear();
      _isSearching = false;
      _emailSentForCurrentStop = false; // Reset just in case
    });
    _initStaticMarkers();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("We will email you when nearing $stopName"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  // --- 4. BUILD UI (Google Maps Style) ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildLeftSidebarContent(),
      endDrawer: _buildRightProfileSidebar(),
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. MAP LAYER
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => setState(() => _isAutoCamera = false),
              child: GoogleMap(
                initialCameraPosition: _initialCamera,
                markers: Set<Marker>.of(_markers.values),
                polylines: Set<Polyline>.of(_polylines.values),
                onMapCreated: (c) {
                  if (!_mapController.isCompleted) _mapController.complete(c);
                },
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),
          ),

          // 2. FLOATING SEARCH BAR (Google Style)
          Positioned(
            top: 60, // Safe Area padding
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30), // Capsule shape
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, color: Colors.black54),
                        onPressed: () =>
                            _scaffoldKey.currentState!.openDrawer(),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: "Search here",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _scaffoldKey.currentState!.openEndDrawer(),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.blue.shade100,
                          child: const Text(
                            "S",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                // Search Results Dropdown
                if (_isSearching)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10),
                      ],
                    ),
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _filteredStops.length,
                      itemBuilder: (context, index) {
                        final stop = _filteredStops[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.place_outlined,
                            color: Colors.black54,
                          ),
                          title: Text(
                            stop['name'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text("Bus: $_busName"),
                          onTap: () => _handleStopSelection(stop['name']),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // 3. BOTTOM INFO CARD (Modern)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: 40,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _busName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Towards $_nextStopName",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.directions_bus,
                              size: 16,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _currentDistance,
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on, color: Colors.green),
                    ),
                    title: const Text(
                      "Next Stop",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    subtitle: Text(
                      _nextStopName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    trailing: FloatingActionButton.small(
                      elevation: 0,
                      backgroundColor: _isAutoCamera
                          ? Colors.blue
                          : Colors.grey.shade200,
                      child: Icon(
                        Icons.my_location,
                        color: _isAutoCamera ? Colors.white : Colors.black54,
                      ),
                      onPressed: () {
                        setState(() => _isAutoCamera = true);
                        _mapController.future.then(
                          (c) => c.animateCamera(
                            CameraUpdate.newLatLng(_busLocation),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            right: 16,
            bottom: 240,
            child: FloatingActionButton(
              heroTag: "gps_btn",
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _goToMyLocation,
              child: const Icon(Icons.near_me, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // --- SIDEBAR CONTENT ---
  Widget _buildLeftSidebarContent() {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            accountName: Text(
              _driverName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text("Route ID: $_busName"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Colors.blue, size: 30),
            ),
          ),
          ..._stops.map((stop) {
            final isSelected = stop['name'] == _userSelectedStopName;
            return ListTile(
              leading: Icon(
                Icons.place,
                color: isSelected ? Colors.green : Colors.grey,
              ),
              title: Text(
                stop['name'],
                style: TextStyle(
                  color: isSelected ? Colors.green : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              subtitle: Text(stop['time']),
              onTap: () {
                Navigator.pop(context); // Close drawer
                _handleStopSelection(stop['name']);
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildRightProfileSidebar() {
    final user = FirebaseAuth.instance.currentUser;
    return Drawer(
      width: 280,
      child: Column(
        children: [
          const SizedBox(height: 50),
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blue.shade100,
            child: Text(
              (user?.displayName ?? "U")[0].toUpperCase(),
              style: const TextStyle(fontSize: 30, color: Colors.blue),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            user?.displayName ?? "User",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
          const Divider(height: 40),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Log Out"),
            onTap: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
    );
  }
}
