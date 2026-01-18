import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool isVideoTabSelected = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              top: 121,
              left: 0,
              right: 0,
              child: Container(
                height: 796,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(
                      'https://www.figma.com/api/mcp/asset/470b72ca-41fd-450b-a19d-a09c2ee1411c',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Header with FLATGROUND title
            Positioned(
              top: -25,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  height: 53,
                  width: 236,
                  decoration: BoxDecoration(
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Stack(
                      children: [
                        // Stroke/outline effect
                        Text(
                          'FLATGROUND',
                          style: GoogleFonts.notable(
                            fontSize: 24,
                            foreground: Paint()
                              ..style = PaintingStyle.stroke
                              ..strokeWidth = 2
                              ..color = Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        // Fill text
                        Text(
                          'FLATGROUND',
                          style: GoogleFonts.notable(
                            fontSize: 24,
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Navigation tabs
            Positioned(
              top: 48,
              left: 0,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isVideoTabSelected = false;
                  });
                },
                child: Container(
                  width: 206,
                  height: 53.5,
                  padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 4),
                  decoration: BoxDecoration(
                    color: isVideoTabSelected ? Colors.white : const Color(0xFFC7C1E4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://www.figma.com/api/mcp/asset/f138ecf0-9ee6-43c6-a1fb-00bd6f73fdea',
                        width: 37.5,
                        height: 37.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              top: 48,
              left: 206,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    isVideoTabSelected = true;
                  });
                },
                child: Container(
                  width: 206,
                  height: 53.5,
                  padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 0),
                  decoration: BoxDecoration(
                    color: isVideoTabSelected ? const Color(0xFFC7C1E4) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.network(
                        'https://www.figma.com/api/mcp/asset/72f6d61e-4f31-476d-9bd1-ebe119322e7d',
                        width: 46,
                        height: 46,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tab labels
            Positioned(
              top: 57,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Spot',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: const Color(0x2B2F00FF),
                    ),
                  ),
                  const SizedBox(width: 40),
                  Text(
                    'Map',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: const Color(0x2B2F00FF),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable content
            Positioned(
              top: 121,
              left: 26,
              right: 26,
              bottom: 0,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    // Video recording card
                    _buildVideoCard(),
                    const SizedBox(height: 27),
                    // Statistics card
                    _buildStatisticsCard(),
                    const SizedBox(height: 30),
                    // Trick history card
                    _buildTrickHistoryCard(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard() {
    return Container(
      width: 360,
      height: 369,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFFC7C1E4), width: 1),
      ),
      child: Stack(
        children: [
          // Video preview area
          Positioned(
            top: 22,
            left: 26,
            right: 26,
            child: Container(
              height: 246,
              decoration: BoxDecoration(
                color: const Color(0x1AC7C1E4),
                borderRadius: BorderRadius.circular(27),
              ),
              child: Stack(
                children: [
                  // Dashed border placeholder
                  Positioned(
                    top: 21,
                    left: 25,
                    right: 25,
                    bottom: 21,
                    child: CustomPaint(
                      painter: DashedBorderPainter(),
                      child: Center(
                        child: Image.network(
                          'https://www.figma.com/api/mcp/asset/ac657086-3396-4c95-8409-65cbccc354aa',
                          width: 48,
                          height: 48,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Record button
          Positioned(
            bottom: 50,
            left: 36,
            child: Container(
              width: 120,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF2F00FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2F00FF), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://www.figma.com/api/mcp/asset/6846e0a3-713c-4db2-a642-cd63d8851701',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'RECORD',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Upload button
          Positioned(
            bottom: 50,
            right: 36,
            child: Container(
              width: 120,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2F00FF), width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.network(
                    'https://www.figma.com/api/mcp/asset/7541c9d0-537c-4e10-a501-637cc2a6a639',
                    width: 24,
                    height: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'UPLOAD',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2F00FF),
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

  Widget _buildStatisticsCard() {
    return Container(
      width: 360,
      height: 540,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFFC7C1E4), width: 1),
      ),
      child: Stack(
        children: [
          // Background circle
          Positioned(
            top: -42,
            right: -62,
            child: Image.network(
              'https://www.figma.com/api/mcp/asset/9c30d54b-055a-4417-81bf-03784a9a1636',
              width: 273,
              height: 256,
            ),
          ),

          // Performed Trick section
          Positioned(
            top: 37,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                children: [
                  Text(
                    'Performed Trick',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      color: const Color(0xFFC7C1E4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'OLLIE',
                    style: GoogleFonts.poppins(
                      fontSize: 40,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2F00FF),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Accuracy percentage
          Positioned(
            top: 45,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '67%',
                  style: GoogleFonts.poppins(
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    color: const Color(0x70180081),
                  ),
                ),
                Text(
                  'accuracy',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: const Color(0x21180081),
                  ),
                ),
              ],
            ),
          ),

          // Statistics section
          Positioned(
            top: 149,
            left: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statistics',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    color: const Color(0xFFC7C1E4),
                  ),
                ),
                const SizedBox(height: 8),
                _buildStatRow('Pop', '85%'),
                const SizedBox(height: 8),
                _buildStatRow('Board rotation', '60%'),
                const SizedBox(height: 8),
                _buildStatRow('Confidence', '56%'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 32,
            color: const Color(0xFF2F00FF),
          ),
        ),
        const SizedBox(width: 20),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: const Color(0x70180081),
          ),
        ),
      ],
    );
  }

  Widget _buildTrickHistoryCard() {
    return Container(
      width: 360,
      height: 540,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFFC7C1E4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 25),
          Center(
            child: Column(
              children: [
                Text(
                  'Trick History',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    color: const Color(0xFFC7C1E4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ' ',
                  style: GoogleFonts.poppins(
                    fontSize: 40,
                    color: const Color(0xFF2F00FF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _buildTrickHistoryItem('Ollie', '67%', 'Just now', 0),
          const SizedBox(height: 29),
          _buildTrickHistoryItem('Treflip', '100%', '1 hour ago', 1),
          const SizedBox(height: 29),
          _buildTrickHistoryItem('Kickflip', '82%', 'This morning', 2),
          const SizedBox(height: 29),
          _buildTrickHistoryItem('Shove-it', '31%', 'Yesterday', 3),
          const SizedBox(height: 29),
          _buildTrickHistoryItem('Backside 180', '96%', 'Last week', 4),
        ],
      ),
    );
  }

  Widget _buildTrickHistoryItem(String trickName, String percentage, String time, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 42),
      child: Container(
        height: 59,
        decoration: BoxDecoration(
          color: const Color(0xFFC7C1E4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Center(
                child: Text(
                  trickName,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2F00FF),
                  ),
                ),
              ),
            ),
            Text(
              percentage,
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: const Color(0x70180081),
              ),
            ),
            const SizedBox(width: 20),
            Text(
              time,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: const Color(0x70180081),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for dashed border
class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x9F000000)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;

    // Top border
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    // Bottom border
    startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height),
        Offset(startX + dashWidth, size.height),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    // Left border
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }

    // Right border
    startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width, startY),
        Offset(size.width, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
