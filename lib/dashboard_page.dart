import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget rowData(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget stopTile(String name, String time) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          Text(
            time,
            style: GoogleFonts.montserrat(color: Colors.black54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double fullWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: SingleChildScrollView(
          scrollDirection: Axis
              .horizontal, // allows full dashboard to scroll on small screens
          child: SizedBox(
            width: fullWidth < 1000 ? 1000 : fullWidth, // minimum width
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ========================= SIDEBAR =========================
                SizedBox(
                  width: 300,
                  child: SingleChildScrollView(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(blurRadius: 12, color: Colors.black12),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sidebar Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.black.withOpacity(.08),
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  height: 50,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E3A8A),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Bus #247",
                                      style: GoogleFonts.montserrat(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      "Campus Express",
                                      style: GoogleFonts.montserrat(
                                        fontSize: 14,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ETA BOX
                          Container(
                            margin: const EdgeInsets.all(18),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade100,
                                  Colors.blue.shade50,
                                ],
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Next Stop",
                                  style: GoogleFonts.montserrat(
                                    color: Colors.black54,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Park Avenue",
                                  style: GoogleFonts.montserrat(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.timer,
                                      color: Colors.blue,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "8 min",
                                      style: GoogleFonts.montserrat(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Stops Title
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18.0,
                            ),
                            child: Text(
                              "Route Stops",
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Stops List
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18.0,
                            ),
                            child: Column(
                              children: [
                                stopTile("Central Station", "15 min"),
                                stopTile("Park Avenue (Next)", "8 min"),
                                stopTile("School Campus", "13 min"),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ========================= MAIN AREA =========================
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white, // empty space
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 12,
                            color: Colors.black.withOpacity(.10),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Stack(
                          children: [
                            // LEFT FLOAT CARD
                            Positioned(
                              left: 0,
                              top: 0,
                              child: Container(
                                width: 260,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 12,
                                      color: Colors.black.withOpacity(.12),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Bus Status",
                                      style: GoogleFonts.montserrat(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    rowData("Bus No", "TN 45 BC 3542"),
                                    rowData("Driver", "Mr. Kumar"),
                                    rowData("Distance", "3.2 km away"),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(
                              height: 600,
                            ), // space for floating cards
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
