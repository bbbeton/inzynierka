import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'camera_screen.dart';
import 'map_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 1; // 0 = Map, 1 = Camera

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Tab content
          IndexedStack(
            index: _currentIndex,
            children: const [
              MapScreen(),
              CameraScreen(),
            ],
          ),

          // Header with tabs
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 130,
              color: Colors.white,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // FLATGROUND Title - upper left corner
                  Positioned(
                    top: 8,
                    left: 16,
                    child: Text(
                      'FLATGROUND',
                      style: GoogleFonts.notable(
                        fontSize: 20,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF2F00FF),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                    
                    // Navigation Tabs
                    Positioned(
                      top: 48,
                      left: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              // Spot Map Tab
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _currentIndex = 0;
                                    });
                                  },
                                  child: Container(
                                    height: 53.5,
                                    decoration: BoxDecoration(
                                      color: _currentIndex == 0 
                                          ? const Color(0xFFC7C1E4) 
                                          : Colors.white,
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.map_outlined,
                                        color: _currentIndex == 0
                                            ? const Color(0xFF2F00FF)
                                            : const Color(0xFF2F00FF).withOpacity(0.3),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Video/Camera Tab
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _currentIndex = 1;
                                    });
                                  },
                                  child: Container(
                                    height: 53.5,
                                    decoration: BoxDecoration(
                                      color: _currentIndex == 1 
                                          ? const Color(0xFFC7C1E4) 
                                          : Colors.white,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        bottomLeft: Radius.circular(12),
                                      ),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.videocam,
                                        color: _currentIndex == 1
                                            ? const Color(0xFF2F00FF)
                                            : const Color(0xFF2F00FF).withOpacity(0.3),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Text label for unselected tab - positioned below tabs
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: Text(
                                _currentIndex == 0 ?'Spot Map' : 'Detect Trick',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: const Color(0xFF2F00FF).withOpacity(0.17),
                                  fontWeight: FontWeight.w400,
                                ),
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
        ],
      ),
    );
  }
}
