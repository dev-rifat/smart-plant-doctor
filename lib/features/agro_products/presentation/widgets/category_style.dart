import 'package:flutter/material.dart';
import 'package:plant_health/features/agro_products/domain/entities/agro_product.dart';

/// Accent colour per category so farmers can tell product types apart at a
/// glance (e.g. red = insecticide) without reading the label.
extension ProductCategoryStyle on ProductCategory {
  Color get color => switch (this) {
    ProductCategory.fungicide => const Color(0xFF6A4FB3),
    ProductCategory.insecticide => const Color(0xFFD84343),
    ProductCategory.miticide => const Color(0xFFE07B39),
    ProductCategory.herbicide => const Color(0xFF8D7B28),
    ProductCategory.fertilizer => const Color(0xFF2E7D32),
    ProductCategory.micronutrient => const Color(0xFF1E88A8),
    ProductCategory.growthRegulator => const Color(0xFF3F7DD8),
    ProductCategory.organic => const Color(0xFF4F9A3A),
  };

  Color get softColor => color.withValues(alpha: 0.12);
}
