import 'package:flutter/material.dart';
import 'package:plant_health/features/plant_detection/domain/entities/plant_analysis_result.dart';

/// Widget to show comprehensive plant analysis results
class ResultCard extends StatelessWidget {
  final bool isHealthy;
  final String disease;
  final String bengaliDisease;
  final String symptoms;
  final String bengaliSymptoms;
  final String treatment;
  final String advice;
  final List<MedicineDetail> medicines;
  final List<RecoveryStep> recoveryPlan;
  final String severity;
  final VoidCallback? onScanAgain;

  const ResultCard({
    Key? key,
    required this.isHealthy,
    required this.disease,
    required this.bengaliDisease,
    required this.symptoms,
    required this.bengaliSymptoms,
    required this.treatment,
    required this.advice,
    required this.medicines,
    required this.recoveryPlan,
    required this.severity,
    this.onScanAgain,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: isHealthy
          ? _buildHealthyView(context)
          : _buildDiseasedView(context),
    );
  }

  Widget _buildDiseasedView(BuildContext context) {
    final displayDisease = bengaliDisease.trim().isNotEmpty
        ? bengaliDisease
        : disease;
    final displaySymptoms = bengaliSymptoms.trim().isNotEmpty
        ? bengaliSymptoms
        : symptoms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF66BB6A), size: 15),
            const SizedBox(width: 6),
            Text(
              'সফলভাবে রোগ শনাক্ত করা হয়েছে!',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: const Color(0xFF66BB6A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          displayDisease,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1D1D1D),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTag('পাতা বিশ্লেষণ'),
            _buildTag('রোগ শনাক্ত'),
            _buildTag(_severityBangla(severity)),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'বিস্তারিত বিবরণ',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          '${displaySymptoms.trim()}\n\n${advice.trim()}',
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.4,
            color: const Color(0xFF3F3F3F),
          ),
        ),
        if (medicines.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'প্রয়োজনীয় ওষুধ',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...medicines.map((med) => _buildMedicineCard(context, med)),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () =>
                _showDetailSheet(context, displayDisease, displaySymptoms),
            icon: const Icon(Icons.arrow_circle_right_outlined, size: 18),
            label: const Text('চিকিৎসা ও প্রতিরোধ দেখুন'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF56DB69),
              foregroundColor: const Color(0xFF0F3816),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onScanAgain,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('আবার পরীক্ষা করুন'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF56A62A),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  void _showDetailSheet(
    BuildContext context,
    String displayDisease,
    String displaySymptoms,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        maxChildSize: 0.96,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              'চিকিৎসা ও প্রতিরোধ',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _sheetSection(context, 'রোগের নাম', displayDisease),
            _sheetSection(context, 'লক্ষণ', displaySymptoms),
            _sheetSection(context, 'চিকিৎসা পদ্ধতি', treatment),
            if (medicines.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'ব্যবহারযোগ্য ওষুধ',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...medicines.map((med) => _buildMedicineCard(context, med)),
            ],
            if (recoveryPlan.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'পুনরুদ্ধারের ধাপ',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ...recoveryPlan.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF56A62A),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          'দিন ${e.day}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.bengaliAction.trim().isNotEmpty
                              ? e.bengaliAction
                              : e.action,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            _sheetSection(context, 'পরামর্শ', advice),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(BuildContext context, MedicineDetail med) {
    final displayName = med.bengaliName.trim().isNotEmpty
        ? med.bengaliName
        : med.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6FBF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0EACC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(13),
              bottomLeft: Radius.circular(13),
            ),
            child: Image.network(
              med.imageUrl,
              width: 90,
              height: 100,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 90,
                height: 100,
                color: const Color(0xFFDEF0DE),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.medication_rounded,
                  color: Color(0xFF56A62A),
                  size: 38,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A3D1E),
                    ),
                  ),
                  Text(
                    med.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF888888),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F3E1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      med.type,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF2A6E30),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (med.usecase.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      med.usecase,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF4F4F4F),
                        height: 1.35,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.science_outlined,
                        size: 13,
                        color: Color(0xFF56A62A),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'মাত্রা: ${med.dosage}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: const Color(0xFF2A7030),
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthyView(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 10),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFE24D),
          ),
          child: const Icon(
            Icons.sentiment_satisfied_alt_rounded,
            color: Color(0xFF5B4A00),
            size: 40,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: 66,
          height: 66,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFE7F3DD),
          ),
          child: const Icon(
            Icons.check_rounded,
            color: Color(0xFF69A74A),
            size: 34,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'সুস্থ আছে',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D1D1D),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'কোনো দৃশ্যমান রোগের লক্ষণ পাওয়া যায়নি।',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onScanAgain,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('আবার পরীক্ষা করুন'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF56A62A),
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1F2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF667079),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _sheetSection(BuildContext context, String title, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: const Color(0xFF3A3A3A),
            ),
          ),
        ],
      ),
    );
  }

  String _severityBangla(String value) {
    final v = value.toLowerCase();
    if (v.contains('severe') || v.contains('গুরুতর')) return 'গুরুতর';
    if (v.contains('moderate') || v.contains('মধ্যম')) return 'মধ্যম';
    return 'হালকা';
  }
}
