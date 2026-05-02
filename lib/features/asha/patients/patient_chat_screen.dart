import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/endpoints.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

class PatientChatScreen extends StatefulWidget {
  final PatientModel patient;
  const PatientChatScreen({super.key, required this.patient});

  @override
  State<PatientChatScreen> createState() => _PatientChatScreenState();
}

class _PatientChatScreenState extends State<PatientChatScreen> {
  static const _storage = FlutterSecureStorage();
  final _ctrl = TextEditingController();
  final _messages = <_ChatMessage>[];
  bool _sending = false;

  String get _key => 'patient_chat_${widget.patient.id.isNotEmpty ? widget.patient.id : widget.patient.name}';

  static const _medicalKeywords = [
    'fever', 'cough', 'pain', 'headache', 'vomit', 'vomiting', 'diarrhea',
    'symptom', 'medicine', 'dose', 'tablet', 'pregnant', 'blood', 'sugar',
    'bp', 'pressure', 'infection', 'injury', 'wound', 'rash', 'breath',
    'chest', 'doctor', 'triage', 'health', 'medical', 'disease',
    'बुखार', 'खांसी', 'दर्द', 'दवा', 'लक्षण', 'गर्भ', 'डॉक्टर',
    'ಜ್ವರ', 'ಕೆಮ್ಮು', 'ನೋವು', 'ಔಷಧ', 'ಲಕ್ಷಣ', 'ಗರ್ಭ', 'ವೈದ್ಯ',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) {
      _messages.add(
        _ChatMessage(
          role: 'assistant',
          text: context.tr('Hello! I can help with patient medicine and health questions. What would you like to ask?'),
          at: DateTime.now(),
        ),
      );
      await _saveHistory();
      if (mounted) setState(() {});
      return;
    }
    final list = jsonDecode(raw) as List<dynamic>;
    setState(() {
      _messages
        ..clear()
        ..addAll(list.map((e) => _ChatMessage.fromJson(Map<String, dynamic>.from(e))));
    });
  }

  Future<void> _saveHistory() async {
    await _storage.write(
      key: _key,
      value: jsonEncode(_messages.map((e) => e.toJson()).toList()),
    );
  }

  String _buildPrompt(String userInput) {
    final p = widget.patient;
    final recent = _messages.take(8).map((m) => '${m.role}: ${m.text}').join('\n');
    final language = Localizations.localeOf(context).languageCode;
    final responseLanguage = language == 'hi'
        ? 'Hindi'
        : language == 'kn'
            ? 'Kannada'
            : 'English';
    return 'Patient context:\n'
        'Name: ${p.name}\n'
        'Age: ${p.age ?? 'unknown'}\n'
        'Gender: ${p.gender ?? 'unknown'}\n'
        'Village: ${p.village ?? '-'}\n'
        'Tehsil: ${p.tehsil ?? '-'}\n'
        'District: ${p.district ?? '-'}\n'
        'Pregnant: ${p.pregnant}\n\n'
        'Recent conversation:\n$recent\n\n'
        'User question: $userInput\n'
        'Rules:\n'
        '- You are a medical-only assistant for ASHA field work.\n'
        '- If question is non-medical, refuse briefly and ask a medicine-related question.\n'
        '- Always include emergency red flags when relevant.\n'
        '- Keep response practical for primary care.\n'
        '- Respond only in $responseLanguage.\n';
  }

  bool _isMedicalQuery(String input) {
    final lower = input.toLowerCase();
    return _medicalKeywords.any(lower.contains);
  }

  Future<void> _send() async {
    final input = _ctrl.text.trim();
    if (input.isEmpty || _sending) return;

    if (!_isMedicalQuery(input)) {
      setState(() {
        _messages.add(_ChatMessage(role: 'user', text: input, at: DateTime.now()));
        _messages.add(
          _ChatMessage(
            role: 'assistant',
            text: context.tr('I can only help with medical or medicine-related questions for this patient.'),
            at: DateTime.now(),
          ),
        );
        _ctrl.clear();
      });
      await _saveHistory();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(role: 'user', text: input, at: DateTime.now()));
      _sending = true;
      _ctrl.clear();
    });
    await _saveHistory();

    final fallback = context.tr('AI unavailable. Please try again.');
    String reply;
    try {
      final res = await ApiClient().dio.post(
        ApiEndpoints.aiSuggestion,
        data: {
          'symptoms': [_buildPrompt(input)],
          'severity': 'yellow',
          'patient_gender': widget.patient.gender ?? 'unknown',
          'patient_age': widget.patient.age ?? 0,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      reply = (res.data['suggestion'] ?? fallback).toString();
    } catch (_) {
      reply = fallback;
    }

    setState(() {
      _messages.add(_ChatMessage(role: 'assistant', text: reply, at: DateTime.now()));
      _sending = false;
    });
    await _saveHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${context.tr('Patient AI Chat')} - ${widget.patient.name}')),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (context, i) {
                  final m = _messages[i];
                  final mine = m.role == 'user';
                  return Align(
                    alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: const BoxConstraints(maxWidth: 320),
                      decoration: BoxDecoration(
                        color: mine ? AppColors.primary : AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        m.text,
                        style: TextStyle(
                          color: mine ? Colors.white : AppColors.textPrimary,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: context.tr('Type your question...'),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String role;
  final String text;
  final DateTime at;
  _ChatMessage({required this.role, required this.text, required this.at});

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        'at': at.toIso8601String(),
      };

  factory _ChatMessage.fromJson(Map<String, dynamic> json) => _ChatMessage(
        role: json['role'] as String,
        text: json['text'] as String,
        at: DateTime.parse(json['at'] as String),
      );
}
