import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Broad grouping used for filter chips and for giving the AI a hint about
/// what kind of problem a product solves.
enum ProductCategory {
  fungicide('ছত্রাকনাশক', 'Fungicide', Icons.coronavirus_rounded),
  insecticide('কীটনাশক', 'Insecticide', Icons.bug_report_rounded),
  miticide('মাকড়নাশক', 'Miticide', Icons.pest_control_rounded),
  herbicide('আগাছানাশক', 'Herbicide', Icons.grass_rounded),
  fertilizer('সার', 'Fertilizer', Icons.spa_rounded),
  micronutrient('অণুখাদ্য', 'Micronutrient', Icons.science_rounded),
  growthRegulator(
    'বৃদ্ধি নিয়ন্ত্রক',
    'Growth regulator',
    Icons.trending_up_rounded,
  ),
  organic('জৈব / বালাইনাশক', 'Organic & bio', Icons.eco_rounded);

  const ProductCategory(this.labelBn, this.labelEn, this.icon);

  final String labelBn;
  final String labelEn;
  final IconData icon;
}

/// A single agro-medicine / farm-input product in the catalog.
class AgroProduct extends Equatable {
  const AgroProduct({
    required this.id,
    required this.nameBn,
    required this.nameEn,
    required this.category,
    required this.activeIngredient,
    required this.company,
    required this.targetCrops,
    required this.targetProblems,
    required this.dosage,
    required this.usage,
    required this.safety,
    required this.packSize,
    required this.price,
  });

  final String id;
  final String nameBn;
  final String nameEn;
  final ProductCategory category;
  final String activeIngredient;
  final String company;
  final List<String> targetCrops;

  /// Diseases / pests / deficiencies this product is used against.
  final List<String> targetProblems;
  final String dosage;
  final String usage;
  final String safety;

  /// Pack the [price] applies to, e.g. "১০০ মিলি".
  final String packSize;

  /// Price in whole Taka per pack. Integers avoid floating-point rounding
  /// errors when summing an order.
  final int price;

  // Products are const, so the index can't be a `late final` field; an
  // Expando memoises it per instance instead of rebuilding on every keystroke.
  static final _searchIndexCache = Expando<String>();

  /// Lower-cased text blob used for local keyword search, so a farmer can
  /// type a crop, pest, ingredient or brand in either language.
  String get searchIndex => _searchIndexCache[this] ??= [
    nameBn,
    nameEn,
    activeIngredient,
    company,
    category.labelBn,
    category.labelEn,
    ...targetCrops,
    ...targetProblems,
  ].join(' ').toLowerCase();

  @override
  List<Object?> get props => [id];
}
