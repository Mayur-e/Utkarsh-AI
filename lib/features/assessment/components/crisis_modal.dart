// lib/features/assessment/components/crisis_modal.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/user_profile.dart';
import '../../../services/storage/database_service.dart';

class CrisisModal extends ConsumerStatefulWidget {
  final Function onSafeConfirmed;

  const CrisisModal({super.key, required this.onSafeConfirmed});

  @override
  ConsumerState<CrisisModal> createState() => _CrisisModalState();
}

class _CrisisModalState extends ConsumerState<CrisisModal> {
  bool _loading = true;
  List<EmergencyContact> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final map = await DatabaseService.instance.getProfile();
    if (mounted && map != null) {
      final profile = UserProfile.fromMap(map);
      setState(() {
        _contacts = profile.emergencyContacts;
        _loading = false;
      });
    } else if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _makeCall(String number) async {
    final url = Uri.parse('tel:$number');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1520),
        body: SafeArea(
          child: _loading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    const Text('💚', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 20),
                    const Text(
                      "You matter. We're here.",
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "You mentioned some difficult thoughts. That takes courage to share. Please reach out to someone who can help right now — it is free and confidential.",
                      style: TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    if (_contacts.isNotEmpty) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Your Emergency Contacts",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ..._contacts.map((c) => _buildContactCard(c)),
                    ] else ...[
                       const Text(
                        "No emergency contacts set. Please consider adding them in your profile settings.",
                        style: TextStyle(color: Colors.white30, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A232E),
                        borderRadius: BorderRadius.circular(12),
                        border: const Border(left: BorderSide(color: Color(0xFF4CAF50), width: 4)),
                      ),
                      child: const Text(
                        "These feelings are temporary, even when they don't feel that way. Reaching out to a trusted contact can help you stay safe.",
                        style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => widget.onSafeConfirmed(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D52),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact c) {
    return Card(
      color: const Color(0xFF161F29),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.greenAccent, width: 0.3),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        title: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(c.relation ?? 'Contact', style: const TextStyle(color: Colors.white38, fontSize: 12)),
        trailing: ElevatedButton(
          onPressed: () => _makeCall(c.number),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text("CALL", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ),
    );
  }
}
