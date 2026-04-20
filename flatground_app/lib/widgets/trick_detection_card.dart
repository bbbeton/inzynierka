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

  String _formatTrickName(String rawName) {
    final normalized = rawName.trim();
    if (normalized.isEmpty || normalized == '---' || normalized == 'Unknown') {
      return normalized;
    }
    const named = {
      'Backside180': 'Backside 180',
      'Frontside180': 'Frontside 180',
      'Kickflip': 'Kickflip',
      'Heelflip': 'Heelflip',
      'Frontshuvit': 'Front Shuv',
      'Shuvit': 'Shuv',
      'Pressureflip': 'Pressureflip',
      'Ollie': 'Ollie',
    };
    if (named.containsKey(normalized)) {
      return named[normalized]!;
    }
    final withSpaces = normalized
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(RegExp(r'([A-Za-z])(\d)'), (m) => '${m[1]} ${m[2]}')
        .replaceAllMapped(RegExp(r'(\d)([A-Za-z])'), (m) => '${m[1]} ${m[2]}');
    return withSpaces;
  }

  @override
  Widget build(BuildContext context) {
    final displayTrick = _formatTrickName(trickName ?? '---');
    final displayAccuracy = accuracy ?? 0;
    final stats = statistics ?? {'confidence': 0};

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 26),
      constraints: const BoxConstraints(maxWidth: 360),
      width: double.infinity,
      height: 300,
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
                    Text(
                      'Performed Trick',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: const Color(0xFFC7C1E4),
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    // Accuracy percentage
                    Column(
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
                  ],
                ),

                const SizedBox(height: 4),
                const SizedBox(height: 2),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    displayTrick,
                    style: GoogleFonts.poppins(
                      fontSize: 28,
                      color: const Color(0xFF2F00FF),
                      fontWeight: FontWeight.w600,
                    ),
                    softWrap: true,
                  ),
                ),

                const SizedBox(height: 18),

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
