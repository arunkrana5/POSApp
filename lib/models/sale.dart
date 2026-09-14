class OfflineSaleItem {
  final int productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double taxPercent;

  OfflineSaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.taxPercent = 0.0,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'taxPercent': taxPercent,
    };
  }
}

class OfflineSale {
  final String clientTransactionId; // Idempotency Client GUID
  final int? customerId;
  final double discountAmount;
  final double paidAmount;
  final String paymentMode;
  final String notes;
  final List<OfflineSaleItem> items;
  final DateTime createdAt;

  OfflineSale({
    required this.clientTransactionId,
    this.customerId,
    required this.discountAmount,
    required this.paidAmount,
    required this.paymentMode,
    required this.notes,
    required this.items,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'clientTransactionId': clientTransactionId,
      'customerId': customerId,
      'discountAmount': discountAmount,
      'paidAmount': paidAmount,
      'paymentMode': paymentMode,
      'notes': notes,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}
