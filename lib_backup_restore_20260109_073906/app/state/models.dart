enum ItemType { product, supply, service, asset }
enum StockPolicy { tracked, notTracked }
enum MoveType { inMove, outMove, adjust }

extension ItemTypeLabel on ItemType {
  String get label {
    switch (this) {
      case ItemType.product:
        return "Producto";
      case ItemType.supply:
        return "Insumo";
      case ItemType.service:
        return "Servicio";
      case ItemType.asset:
        return "Activo";
    }
  }
}

extension MoveTypeLabel on MoveType {
  String get label {
    switch (this) {
      case MoveType.inMove:
        return "Entrada";
      case MoveType.outMove:
        return "Salida";
      case MoveType.adjust:
        return "Ajuste";
    }
  }
}

class InventoryItem {
  final String id;
  final String name;
  final String sku;
  final String unit; // pz, kg, hr, etc.
  final ItemType type;
  final StockPolicy stockPolicy;
  final double minStock;
  final double price;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.unit,
    required this.type,
    required this.stockPolicy,
    required this.minStock,
    required this.price,
  });

  Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
        "sku": sku,
        "unit": unit,
        "type": type.name,
        "stockPolicy": stockPolicy.name,
        "minStock": minStock,
        "price": price,
      };

  static InventoryItem fromMap(Map m) {
    ItemType t = ItemType.product;
    final rawT = (m["type"] ?? "product").toString();
    if (rawT == "supply") t = ItemType.supply;
    if (rawT == "service") t = ItemType.service;
    if (rawT == "asset") t = ItemType.asset;

    StockPolicy sp = StockPolicy.tracked;
    final rawSp = (m["stockPolicy"] ?? "tracked").toString();
    if (rawSp == "notTracked") sp = StockPolicy.notTracked;

    return InventoryItem(
      id: (m["id"] ?? "").toString(),
      name: (m["name"] ?? "").toString(),
      sku: (m["sku"] ?? "").toString(),
      unit: (m["unit"] ?? "pz").toString(),
      type: t,
      stockPolicy: sp,
      minStock: ((m["minStock"] ?? 0) as num).toDouble(),
      price: ((m["price"] ?? 0) as num).toDouble(),
    );
  }
}

class StockMove {
  final String id;
  final DateTime ts;
  final String itemId;
  final MoveType type;
  final double qty; // positiva
  final String note;

  const StockMove({
    required this.id,
    required this.ts,
    required this.itemId,
    required this.type,
    required this.qty,
    required this.note,
  });

  Map<String, dynamic> toMap() => {
        "id": id,
        "ts": ts.toIso8601String(),
        "itemId": itemId,
        "type": type.name,
        "qty": qty,
        "note": note,
      };

  static StockMove fromMap(Map m) {
    MoveType t = MoveType.inMove;
    final raw = (m["type"] ?? "inMove").toString();
    if (raw == "outMove") t = MoveType.outMove;
    if (raw == "adjust") t = MoveType.adjust;

    return StockMove(
      id: (m["id"] ?? "").toString(),
      ts: DateTime.tryParse((m["ts"] ?? "").toString()) ?? DateTime.now(),
      itemId: (m["itemId"] ?? "").toString(),
      type: t,
      qty: ((m["qty"] ?? 0) as num).toDouble(),
      note: (m["note"] ?? "").toString(),
    );
  }
}
