import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TrickHistoryCard extends StatelessWidget {
  final List<Map<String, String>> trickHistory;

  const TrickHistoryCard({
    super.key,
    this.trickHistory = const [],
  });

  @override
  Widget build(BuildContext context) {
    final displayHistory = trickHistory;

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
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 3),
            // Title
            Center(
              child: Text(
                'Trick History',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  color: const Color(0xFFC7C1E4),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            // Trick List
            Expanded(
              child: displayHistory.isEmpty
                  ? Center(
                      child: Text(
                        'No trick history yet.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF180081).withOpacity(0.44),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: displayHistory.length,
                      itemBuilder: (context, index) {
                  final trick = displayHistory[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 29),
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
                          // Trick name
                          Flexible(
                            flex: 2,
                            child: Text(
                              trick['name']!,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF2F00FF),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // Percentage and time
                          Flexible(
                            flex: 3,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Flexible(
                                  child: Text(
                                    trick['percentage']!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      color: const Color(0xFF180081).withOpacity(0.44),
                                      fontWeight: FontWeight.w900,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    trick['time']!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: const Color(0xFF180081).withOpacity(0.44),
                                      fontWeight: FontWeight.w300,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
