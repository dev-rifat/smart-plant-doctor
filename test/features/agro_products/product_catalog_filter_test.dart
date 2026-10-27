import 'package:flutter_test/flutter_test.dart';
import 'package:plant_health/features/agro_products/data/datasources/agro_product_local_datasource.dart';
import 'package:plant_health/features/agro_products/domain/entities/agro_product.dart';
import 'package:plant_health/features/agro_products/presentation/cubit/product_catalog_cubit.dart';

void main() {
  final products = const AgroProductLocalDataSourceImpl().getAllProducts();

  test('catalog ids are unique', () {
    final ids = products.map((p) => p.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('empty query returns everything in the category', () {
    final result = ProductCatalogCubit.filterProducts(
      products,
      '  ',
      ProductCategory.herbicide,
    );
    expect(result, isNotEmpty);
    expect(result.every((p) => p.category == ProductCategory.herbicide), true);
  });

  test(
    'spoken Bangla sentence with suffixes finds rice stem borer products',
    () {
      final result = ProductCatalogCubit.filterProducts(
        products,
        'ধানের মাজরা পোকা',
        null,
      );
      expect(result.first.id, 'virtako-40wg');
    },
  );

  test('English brand search is case-insensitive', () {
    final result = ProductCatalogCubit.filterProducts(
      products,
      'RIDOMIL',
      null,
    );
    expect(result.map((p) => p.id), contains('ridomil-gold'));
  });

  test('no match returns empty list', () {
    final result = ProductCatalogCubit.filterProducts(
      products,
      'xyzqwerty',
      null,
    );
    expect(result, isEmpty);
  });
}
