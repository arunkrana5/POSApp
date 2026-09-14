class Product {
  final int id;
  final String productCode;
  final String name;
  final String category;
  final String unit;
  final String barcode;
  final double purchasePrice;
  final double sellingPrice;
  final double mrp;
  final double currentStock;

  Product({
    required this.id,
    required this.productCode,
    required this.name,
    required this.category,
    required this.unit,
    required this.barcode,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.mrp,
    required this.currentStock,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productCode': productCode,
      'name': name,
      'category': category,
      'unit': unit,
      'barcode': barcode,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'mrp': mrp,
      'currentStock': currentStock,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? 0,
      productCode: map['productCode'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      unit: map['unit'] ?? 'pcs',
      barcode: map['barcode'] ?? '',
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
      currentStock: (map['currentStock'] as num?)?.toDouble() ?? 0.0,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product.fromMap(json);
}
