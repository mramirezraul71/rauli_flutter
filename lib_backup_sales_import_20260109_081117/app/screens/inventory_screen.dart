import 'dart:convert';
import 'package:flutter/material.dart';
import '../state/models.dart';
import '../../main.dart' show AppStateScope;

class InventoryScreenPro extends StatefulWidget {
  const InventoryScreenPro({super.key});

  @override
  State<InventoryScreenPro> createState() => _InventoryScreenProState();
}

class _InventoryScreenProState extends State<InventoryScreenPro> {
  String query = "";

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final items = state.inventoryItems
        .where((i) =>
            i.name.toLowerCase().contains(query.toLowerCase()) ||
            i.sku.toLowerCase().contains(query.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Inventario",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: "Buscar (SKU / Nombre)",
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        onChanged: (v) => setState(() => query = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (_) => const _AddItemDialog(),
                        );
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text("Item"),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (_) => const _ImportCsvDialog(),
                        );
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.upload_file_rounded),
                      label: const Text("Importar CSV"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            if (items.isEmpty)
              const _EmptyCard(
                title: "Sin items",
                subtitle:
                    "Crea items desde cero o importa un CSV (sku,name,unit,stock,min).",
                icon: Icons.inventory_2_rounded,
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      for (final it in items) ...[
                        _ItemRow(item: it),
                        const Divider(height: 18),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final InventoryItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final stock = state.stockOf(item.id);
    final isLow =
        item.stockPolicy == StockPolicy.tracked && stock < item.minStock;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isLow
                ? Colors.red.withOpacity(0.12)
                : Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            isLow ? Icons.warning_amber_rounded : Icons.inventory_2_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("${item.name}  •  ${item.type.label}",
                style: const TextStyle(fontWeight: FontWeight.w900),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text("SKU: ${item.sku} • Unidad: ${item.unit} • Min: ${item.minStock}",
                style: const TextStyle(color: Colors.black54)),
          ]),
        ),
        const SizedBox(width: 8),
        if (item.stockPolicy == StockPolicy.tracked)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Stock",
                  style: TextStyle(
                      color: isLow ? Colors.red : Colors.black54,
                      fontWeight: FontWeight.w800)),
              Text(
                stock.toStringAsFixed(2),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isLow ? Colors.red : Colors.black),
              ),
            ],
          )
        else
          const Text("No controlado",
              style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        FilledButton.tonalIcon(
          onPressed: item.stockPolicy == StockPolicy.tracked
              ? () async {
                  await showDialog(
                    context: context,
                    builder: (_) => _MoveDialog(item: item),
                  );
                }
              : null,
          icon: const Icon(Icons.swap_vert_rounded),
          label: const Text("Mover"),
        ),
      ],
    );
  }
}

class _AddItemDialog extends StatefulWidget {
  const _AddItemDialog();

  @override
  State<_AddItemDialog> createState() => _AddItemDialogState();
}

class _AddItemDialogState extends State<_AddItemDialog> {
  final nameCtrl = TextEditingController();
  final skuCtrl = TextEditingController();
  final unitCtrl = TextEditingController(text: "pz");
  final minCtrl = TextEditingController(text: "0");
  final priceCtrl = TextEditingController(text: "0");

  ItemType type = ItemType.product;
  StockPolicy stockPolicy = StockPolicy.tracked;

  @override
  void dispose() {
    nameCtrl.dispose();
    skuCtrl.dispose();
    unitCtrl.dispose();
    minCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AlertDialog(
      title: const Text("Crear item"),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: "Nombre", prefixIcon: Icon(Icons.badge_rounded)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: skuCtrl,
              decoration: const InputDecoration(
                  labelText: "SKU / Código", prefixIcon: Icon(Icons.qr_code_2_rounded)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: unitCtrl,
                    decoration: const InputDecoration(
                        labelText: "Unidad (pz, kg, hr...)",
                        prefixIcon: Icon(Icons.straighten_rounded)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<ItemType>(
                    value: type,
                    decoration: const InputDecoration(
                      labelText: "Tipo",
                      prefixIcon: Icon(Icons.category_rounded),
                    ),
                    items: ItemType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                        .toList(),
                    onChanged: (v) => setState(() => type = v ?? type),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<StockPolicy>(
                    value: stockPolicy,
                    decoration: const InputDecoration(
                      labelText: "Stock",
                      prefixIcon: Icon(Icons.inventory_2_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: StockPolicy.tracked, child: Text("Controlado")),
                      DropdownMenuItem(value: StockPolicy.notTracked, child: Text("No controlado")),
                    ],
                    onChanged: (v) => setState(() => stockPolicy = v ?? stockPolicy),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: "Stock mínimo",
                        prefixIcon: Icon(Icons.warning_rounded)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Precio (opcional)",
                  prefixIcon: Icon(Icons.attach_money_rounded)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        FilledButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            final sku = skuCtrl.text.trim();
            final unit = unitCtrl.text.trim().isEmpty ? "pz" : unitCtrl.text.trim();

            final min = double.tryParse(minCtrl.text.trim().replaceAll(',', '.')) ?? 0;
            final price = double.tryParse(priceCtrl.text.trim().replaceAll(',', '.')) ?? 0;

            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Nombre requerido.")));
              return;
            }

            state.addInventoryItem(
              InventoryItem(
                id: "i_${DateTime.now().millisecondsSinceEpoch}",
                name: name,
                sku: sku.isEmpty ? name.toLowerCase().replaceAll(" ", "_") : sku,
                unit: unit,
                type: type,
                stockPolicy: stockPolicy,
                minStock: min < 0 ? 0 : min,
                price: price < 0 ? 0 : price,
              ),
            );

            Navigator.pop(context);
          },
          child: const Text("Guardar"),
        ),
      ],
    );
  }
}

class _MoveDialog extends StatefulWidget {
  final InventoryItem item;
  const _MoveDialog({required this.item});

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  MoveType type = MoveType.inMove;
  final qtyCtrl = TextEditingController(text: "1");
  final noteCtrl = TextEditingController();

  @override
  void dispose() {
    qtyCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AlertDialog(
      title: Text("Movimiento • ${widget.item.name}"),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<MoveType>(
              value: type,
              decoration: const InputDecoration(
                labelText: "Tipo de movimiento",
                prefixIcon: Icon(Icons.swap_vert_rounded),
              ),
              items: MoveType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) => setState(() => type = v ?? type),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Cantidad",
                prefixIcon: Icon(Icons.numbers_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: "Nota (opcional)",
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        FilledButton(
          onPressed: () {
            final qty = double.tryParse(qtyCtrl.text.trim().replaceAll(',', '.')) ?? 0;
            if (qty <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cantidad inválida.")));
              return;
            }

            state.addStockMove(
              StockMove(
                id: "m_${DateTime.now().millisecondsSinceEpoch}",
                ts: DateTime.now(),
                itemId: widget.item.id,
                type: type,
                qty: qty,
                note: noteCtrl.text.trim(),
              ),
            );

            Navigator.pop(context);
          },
          child: const Text("Aplicar"),
        ),
      ],
    );
  }
}

class _ImportCsvDialog extends StatefulWidget {
  const _ImportCsvDialog();

  @override
  State<_ImportCsvDialog> createState() => _ImportCsvDialogState();
}

class _ImportCsvDialogState extends State<_ImportCsvDialog> {
  final csvCtrl = TextEditingController();
  String status = "Pega aquí tu CSV (con encabezado).";

  @override
  void dispose() {
    csvCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AlertDialog(
      title: const Text("Importar Inventario (CSV)"),
      content: SizedBox(
        width: 760,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Formato recomendado:\n"
              "sku,name,unit,stock,min\n"
              "A001,Café,pz,10,2\n\n"
              "Acepta coma (,) o punto y coma (;).",
            ),
            const SizedBox(height: 10),
            TextField(
              controller: csvCtrl,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: "Pegar CSV aquí",
                prefixIcon: Icon(Icons.description_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(status, style: const TextStyle(color: Colors.black54)),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar")),
        FilledButton(
          onPressed: () {
            final text = csvCtrl.text.trim();
            if (text.isEmpty) {
              setState(() => status = "CSV vacío.");
              return;
            }

            final parsed = _parseCsv(text);
            if (parsed.isEmpty) {
              setState(() => status = "No se detectaron filas.");
              return;
            }

            int created = 0;
            int applied = 0;

            for (final row in parsed) {
              final sku = (row["sku"] ?? "").trim();
              final name = (row["name"] ?? "").trim();
              final unit = (row["unit"] ?? "pz").trim();
              final stock = double.tryParse((row["stock"] ?? "0").replaceAll(',', '.')) ?? 0;
              final min = double.tryParse((row["min"] ?? "0").replaceAll(',', '.')) ?? 0;

              if (name.isEmpty) continue;

              final itemId = "i_${DateTime.now().millisecondsSinceEpoch}_${created + 1}";
              state.addInventoryItem(
                InventoryItem(
                  id: itemId,
                  name: name,
                  sku: sku.isEmpty ? name.toLowerCase().replaceAll(" ", "_") : sku,
                  unit: unit.isEmpty ? "pz" : unit,
                  type: ItemType.product,
                  stockPolicy: StockPolicy.tracked,
                  minStock: min < 0 ? 0 : min,
                  price: 0,
                ),
              );
              created++;

              if (stock >= 0) {
                state.addStockMove(
                  StockMove(
                    id: "m_${DateTime.now().millisecondsSinceEpoch}_${created + 100}",
                    ts: DateTime.now(),
                    itemId: itemId,
                    type: MoveType.adjust,
                    qty: stock,
                    note: "Import CSV (stock inicial)",
                  ),
                );
                applied++;
              }
            }

            setState(() => status = "Importado: $created items. Stock aplicado: $applied.");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Importado: $created • Stock aplicado: $applied")),
            );
          },
          child: const Text("Importar"),
        ),
      ],
    );
  }

  List<Map<String, String>> _parseCsv(String input) {
    final lines = const LineSplitter()
        .convert(input)
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return [];

    final delimiter =
        lines.first.contains(";") && !lines.first.contains(",") ? ";" : ",";
    final header =
        lines.first.split(delimiter).map((s) => s.trim().toLowerCase()).toList();

    final rows = <Map<String, String>>[];
    for (int i = 1; i < lines.length; i++) {
      final parts = lines[i].split(delimiter);
      final row = <String, String>{};
      for (int c = 0; c < header.length && c < parts.length; c++) {
        row[header[c]] = parts[c].trim();
      }
      rows.add(row);
    }
    return rows;
  }
}

class _EmptyCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _EmptyCard({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
