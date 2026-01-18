import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TrickDetectionCard extends StatelessWidget {
  final String? trickName;
  final int? accuracy;
  final Map<String, int>? statistics;

  const TrickDetectionCard({
    super.key,
    this.trickName,
    this.accuracy,
    this.statistics,
  });

  @override
  Widget build(BuildContext context) {
    final displayTrick = trickName ?? 'OLLIE';
    final displayAccuracy = accuracy ?? 67;
    final stats = statistics ?? {
      'pop': 85,
      'boardRotation': 60,
      'confidence': 56,
    };

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 26),
      constraints: const BoxConstraints(maxWidth: 360),
      width: double.infinity,
      height: 540,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: const Color(0xFFC7C1E4),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Background circle decoration
          Positioned(
            right: -42,
            top: -42,
            child: Container(
              width: 273,
              height: 273,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFF9C4).withOpacity(0.3),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 15),

                // Performed Trick Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Performed Trick',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: const Color(0xFFC7C1E4),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayTrick.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              color: const Color(0xFF2F00FF),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // Accuracy percentage
                    Flexible(
                      flex: 1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$displayAccuracy%',
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              color: const Color(0xFF180081).withOpacity(0.44),
                              fontWeight: FontWeight.w900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'accuracy',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF180081).withOpacity(0.13),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 50),

                // Statistics Section
                Text(
                  'Statistics',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: const Color(0xFFC7C1E4),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),

                // Pop Statistic
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Pop',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: const Color(0xFF2F00FF),
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${stats['pop'] ?? 85}%',
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        color: const Color(0xFF180081).withOpacity(0.44),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Board rotation Statistic
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 2,
                      child: Text(
                        'Board rotation',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: const Color(0xFF2F00FF),
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      flex: 1,
                      child: Text(
                        '${stats['boardRotation'] ?? 60}%',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: const Color(0xFF180081).withOpacity(0.44),
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Confidence Statistic
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 2,
                      child: Text(
                        'Confidence',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: const Color(0xFF2F00FF),
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Flexible(
                      flex: 1,
                      child: Text(
                        '${stats['confidence'] ?? 56}%',
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          color: const Color(0xFF180081).withOpacity(0.44),
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
