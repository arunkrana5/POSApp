class Product {
  final int id;
  final String productCode;
  final String name;
  final String category;
  final String brand;
  final String unit;
  final String barcode;
  final double purchasePrice;
  final double sellingPrice;
  final double mrp;
  final double gstPercent;
  final double currentStock;
  final double minimumStock;
  final String batchNumber;
  final String rackNumber;
  final String expiryDate;
  final String hsnCode;

  Product({
    required this.id,
    required this.productCode,
    required this.name,
    required this.category,
    this.brand = '',
    required this.unit,
    required this.barcode,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.mrp,
    this.gstPercent = 0.0,
    required this.currentStock,
    this.minimumStock = 5.0,
    this.batchNumber = '',
    this.rackNumber = '',
    this.expiryDate = '',
    this.hsnCode = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productCode': productCode,
      'name': name,
      'category': category,
      'brand': brand,
      'unit': unit,
      'barcode': barcode,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'mrp': mrp,
      'gstPercent': gstPercent,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'batchNumber': batchNumber,
      'rackNumber': rackNumber,
      'expiryDate': expiryDate,
      'hsnCode': hsnCode,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? 0,
      productCode: map['productCode'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      brand: map['brand'] ?? '',
      unit: map['unit'] ?? 'pcs',
      barcode: map['barcode'] ?? '',
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? 0.0,
      mrp: (map['mrp'] as num?)?.toDouble() ?? 0.0,
      gstPercent: (map['gstPercent'] as num?)?.toDouble() ?? (map['gstRate'] as num?)?.toDouble() ?? 0.0,
      currentStock: (map['currentStock'] as num?)?.toDouble() ?? 0.0,
      minimumStock: (map['minimumStock'] as num?)?.toDouble() ?? 5.0,
      batchNumber: map['batchNumber'] ?? map['batchNo'] ?? '',
      rackNumber: map['rackNumber'] ?? map['rackNo'] ?? '',
      expiryDate: map['expiryDate'] != null ? map['expiryDate'].toString().split('T')[0] : '',
      hsnCode: map['hsnCode'] ?? '',
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product.fromMap(json);
}
