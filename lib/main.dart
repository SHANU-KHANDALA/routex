import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'firebase_options.dart';
import 'auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // --- ONE-TIME SETUP: Uploads data if it doesn't exist ---
  await uploadMockData();
  // --------------------------------------------------------

  runApp(const MyApp());
}

Future<void> uploadMockData() async {
  final busRef = FirebaseFirestore.instance.collection('buses').doc('bus_247');

  final docSnapshot = await busRef.get();
  if (docSnapshot.exists) {
    print("Database already exists. Skipping upload.");
    return;
  }

  print("Uploading Mock Data to Firestore...");
  await busRef.set({
    'busNumber': 'Bus #247',
    'driverName': 'Campus Express',
    'stops': [
      {
        "id": "1",
        "name": "Acropolis",
        "lat": 22.818023,
        "lng": 75.943507,
        "time": "6:10 AM",
      },
      {
        "id": "2",
        "name": "Bypass Road",
        "lat": 22.817724,
        "lng": 75.938138,
        "time": "6:05 AM",
      },
      {
        "id": "3",
        "name": "Hare Krishna Vihar",
        "lat": 22.754549,
        "lng": 75.934626,
        "time": "6:30 AM",
      },
      {
        "id": "4",
        "name": "Knight Square",
        "lat": 22.754528,
        "lng": 75.930608,
        "time": "6:30 AM",
      },
      {
        "id": "5",
        "name": "Radisson Blu",
        "lat": 22.749603,
        "lng": 75.903561,
        "time": "6:45 AM",
      },
      {
        "id": "6",
        "name": "Vijay Nagar",
        "lat": 22.750783,
        "lng": 75.895587,
        "time": "6:55 AM",
      },
      {
        "id": "7",
        "name": "Bapat Square",
        "lat": 22.755260,
        "lng": 75.878421,
        "time": "7:15 AM",
      },
    ],
  });
  print("Data Uploaded Successfully!");
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RouteX',
      home: AuthGate(),
    );
  }
}
