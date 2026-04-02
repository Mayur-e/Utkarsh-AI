// lib/features/assessment/components/crisis_modal.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class Helpline {
  final String name;
  final String number;
  final String hours;

  Helpline(this.name, this.number, this.hours);
}

final List<Helpline> helplines = [
  Helpline('iCall (TISS Mumbai)', '9152987821', 'Mon–Sat, 8am–10pm'),
  Helpline('Vandrevala Foundation', '18602662345', '24x7 Free'),
  Helpline('NIMHANS Helpline', '08046110007', '24x7'),
  Helpline('National Helpline', '9820466627', '24x7'),
];

class CrisisModal extends StatefulWidget {
  final Function onSafeConfirmed;

  const CrisisModal({super.key, required this.onSafeConfirmed});

  @override
  State<CrisisModal> createState() => _CrisisModalState();
}

class _CrisisModalState extends State<CrisisModal> {
  bool _callMade = false;

  Future<void> _makeCall(String number) async {
    final url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
      setState(() => _callMade = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // IMPORTANT: DISABLES ANDROID BACK BUTTON (Phase 12 Req)
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1520),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Text('💚', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 20),
                const Text(
                  "You matter. We're here.",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "You mentioned some difficult thoughts. That takes courage to share. Please reach out to someone who can help right now — it is free and confidential.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "📞 Free Crisis Support — India",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...helplines.map((h) => _buildHelplineCard(h)),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A232E),
                    borderRadius: BorderRadius.circular(12),
                    border: const Border(
                      left: BorderSide(color: Color(0xFF4CAF50), width: 4),
                    ),
                  ),
                  child: const Text(
                    "These feelings are temporary, even when they don't feel that way. A trained counsellor is available right now who understands exactly what you are going through.",
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  _callMade
                      ? "Thank you for reaching out. Please continue when you feel ready."
                      : "Please tap a helpline above before continuing.",
                  style: const TextStyle(color: Colors.white30, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _callMade ? () => widget.onSafeConfirmed() : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D52),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: Colors.white10,
                    ),
                    child: const Text(
                      "I am safe right now and want to continue",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Immediate danger? Call 112 (Emergency Services)",
                  style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Utkarsh is not a substitute for professional mental health care.",
                  style: TextStyle(color: Colors.white24, fontSize: 10),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelplineCard(Helpline h) {
    return Card(
      color: const Color(0xFF161F29),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.greenAccent, width: 0.3),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(h.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(h.number, style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
            Text(h.hours, style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () => _makeCall(h.number),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("CALL", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
