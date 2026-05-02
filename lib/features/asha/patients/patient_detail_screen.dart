import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_theme.dart';

class PatientDetailScreen extends StatelessWidget {
  final PatientModel patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Patient Details'))),
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _DetailTile(label: context.tr('Full Name *'), value: patient.name),
            _DetailTile(label: context.tr('Age'), value: patient.age?.toString() ?? '-'),
            _DetailTile(label: context.tr('Gender'), value: patient.gender ?? '-'),
            _DetailTile(label: context.tr('Village'), value: patient.village ?? '-'),
            _DetailTile(label: context.tr('Tehsil'), value: patient.tehsil ?? '-'),
            _DetailTile(label: context.tr('District'), value: patient.district ?? '-'),
            _DetailTile(label: context.tr('ABHA ID (optional)'), value: patient.abhaId ?? '-'),
            _DetailTile(
              label: context.tr('Pregnant'),
              value: patient.pregnant ? context.tr('Yes') : context.tr('No'),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/asha/patients/chat', extra: patient),
              icon: const Icon(Icons.chat_rounded),
              label: Text(context.tr('Chat with AI for this patient')),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;
  const _DetailTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
