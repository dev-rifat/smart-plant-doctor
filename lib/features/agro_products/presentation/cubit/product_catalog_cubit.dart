import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plant_health/features/agro_products/domain/entities/agro_product.dart';

class ProductCatalogState extends Equatable {
  const ProductCatalogState({
    required this.visibleProducts,
    this.query = '',
    this.category,
  });

  final List<AgroProduct> visibleProducts;
  final String query;

  /// null means "all categories".
  final ProductCategory? category;

  @override
  List<Object?> get props => [visibleProducts, query, category];
}

/// Local, offline search + category filter over the bundled catalog.
class ProductCatalogCubit extends Cubit<ProductCatalogState> {
  ProductCatalogCubit(this._allProducts)
    : super(ProductCatalogState(visibleProducts: _allProducts));

  final List<AgroProduct> _allProducts;

  void search(String query) {
    // Voice partials often repeat the same text; skip redundant filtering.
    if (query == state.query) return;
    _apply(query: query, category: state.category);
  }

  void selectCategory(ProductCategory? category) =>
      _apply(query: state.query, category: category);

  void _apply({required String query, ProductCategory? category}) {
    emit(
      ProductCatalogState(
        visibleProducts: filterProducts(_allProducts, query, category),
        query: query,
        category: category,
      ),
    );
  }

  // Bangla possessive/locative endings, longest first, so "ধানের" or
  // "টমেটোতে" still match catalog words "ধান" / "টমেটো".
  static const _banglaSuffixes = ['য়ের', 'ের', 'এর', 'তে', 'কে', 'র'];

  static String _stem(String token) {
    for (final s in _banglaSuffixes) {
      if (token.length > s.length + 1 && token.endsWith(s)) {
        return token.substring(0, token.length - s.length);
      }
    }
    return token;
  }

  /// Ranks products by how many query words they match, so a spoken
  /// sentence like "ধানের মাজরা পোকা" surfaces the best matches first
  /// instead of requiring every word to appear.
  static List<AgroProduct> filterProducts(
    List<AgroProduct> products,
    String query,
    ProductCategory? category,
  ) {
    final inCategory = category == null
        ? products
        : products.where((p) => p.category == category).toList();

    final tokens = query
        .toLowerCase()
        .split(RegExp(r'[\s,।?!.]+'))
        .where((t) => t.length >= 2)
        .map(_stem)
        .toList();
    if (tokens.isEmpty) return inCategory;

    // Keep the catalog position alongside the score for a stable tie-break
    // (List.sort isn't guaranteed stable).
    final scored = <({AgroProduct product, int score, int order})>[];
    for (var i = 0; i < inCategory.length; i++) {
      final index = inCategory[i].searchIndex;
      final score = tokens.where(index.contains).length;
      if (score > 0) {
        scored.add((product: inCategory[i], score: score, order: i));
      }
    }
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.order.compareTo(b.order);
    });
    return scored.map((e) => e.product).toList();
  }
}
