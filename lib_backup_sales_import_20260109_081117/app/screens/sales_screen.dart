import 'package:flutter/material.dart';
import '../../main.dart' show AppStateScope;

class SalesScreenPro extends StatefulWidget {
  const SalesScreenPro({super.key});

  @override
  State<SalesScreenPro> createState() => _SalesScreenProState();
}

class _SalesScreenProState extends State<SalesScreenPro> {
  final amountCtrl = TextEditingController(text: "0.00");

  @override
  void dispose() {
    amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "Ventas",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openImportDialog(context),
                  icon: const Icon(Icons.cloud_download_rounded),
                  label: const Text("Importar"),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: amountCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Registrar venta manual",
                          prefixIcon: Icon(Icons.edit_rounded),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        final v =
                            double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
                        if (v <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Monto inválido.")),
                          );
                          return;
                        }
                        state.addSale(amount: v, method: "Efectivo", type: "Manual");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Venta registrada: \$${v.toStringAsFixed(2)}")),
                        );
                        amountCtrl.text = "0.00";
                      },
                      icon: const Icon(Icons.check_rounded),
                      label: const Text("Guardar"),
                    ),
                    const SizedBox(width: 18),
                    Text(
                      "Total hoy: \$ ${state.todaySalesTotal.toStringAsFixed(2)}  •  Órdenes: ${state.todayOrdersCount}",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Historial", style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (state.sales.isEmpty)
                    const Text("No hay ventas registradas.", style: TextStyle(color: Colors.black54))
                  else
                    ...state.sales.take(50).map((s) {
                      final amount = ((s["amount"] ?? 0) as num).toDouble();
                      final type = (s["type"] ?? "").toString();
                      final method = (s["method"] ?? "").toString();
                      final ts = DateTime.tryParse((s["ts"] ?? "").toString());
                      final stamp = ts == null
                          ? "--/-- --:--"
                          : "${ts.month.toString().padLeft(2, '0')}/${ts.day.toString().padLeft(2, '0')}  ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}";
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "$stamp • $type • $method",
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                            Text("\$ ${amount.toStringAsFixed(2)}",
                                style: const TextStyle(fontWeight: FontWeight.w900)),
                          ],
                        ),
                      );
                    }),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openImportDialog(BuildContext context) async {
    final state = AppStateScope.of(context);
    final textCtrl = TextEditingController();

    // CSV recomendado:
    // ts,amount,method,type
    // 2026-01-09 07:45,100,Efectivo,Rápida
    // o ISO: 2026-01-09T07:45:00,100,Efectivo,Manual

    int imported = 0;

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Importar Ventas"),
          content: SizedBox(
            width: 760,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _HintCard(),
                const SizedBox(height: 10),
                TextField(
                  controller: textCtrl,
                  minLines: 10,
                  maxLines: 16,
                  decoration: const InputDecoration(
                    labelText: "Pega aquí CSV (ts,amount,method,type)",
                    hintText:
                        "ts,amount,method,type\n2026-01-09 07:45,100,Efectivo,Rápida\n2026-01-09 08:10,50,Card,Manual",
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Conectores (POS/ERP) (próximo): Square, Shopify, Clover, Lightspeed, Odoo, QuickBooks, etc.",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            FilledButton.icon(
              onPressed: () {
                final raw = textCtrl.text.trim();
                if (raw.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Pega un CSV primero.")),
                  );
                  return;
                }

                final result = _parseCsvSales(raw);
                imported = 0;

                for (final row in result) {
                  state.addSaleAt(
                    ts: row.ts,
                    amount: row.amount,
                    method: row.method,
                    type: row.type,
                  );
                  imported++;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Importadas: $imported ventas ✅")),
                );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.file_download_rounded),
              label: const Text("Importar"),
            ),
          ],
        );
      },
    );

    textCtrl.dispose();
  }

  List<_CsvSaleRow> _parseCsvSales(String raw) {
    // Soporta , o ; como separador.
    final lines = raw
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return [];

    // Si hay header, lo saltamos
    final first = lines.first.toLowerCase();
    int start = 0;
    if (first.contains("amount") && (first.contains("ts") || first.contains("date"))) {
      start = 1;
    }

    final out = <_CsvSaleRow>[];

    for (int i = start; i < lines.length; i++) {
      final line = lines[i];

      final parts = line.contains(";") ? line.split(";") : line.split(",");
      if (parts.length < 2) continue;

      final tsStr = (parts.length >= 1 ? parts[0].trim() : "");
      final amountStr = (parts.length >= 2 ? parts[1].trim() : "0");
      final methodStr = (parts.length >= 3 ? parts[2].trim() : "Efectivo");
      final typeStr = (parts.length >= 4 ? parts[3].trim() : "Import");

      final amount = double.tryParse(amountStr.replaceAll(',', '.')) ?? 0;
      if (amount <= 0) continue;

      DateTime ts = DateTime.now();
      final t1 = DateTime.tryParse(tsStr);
      if (t1 != null) {
        ts = t1;
      } else {
        // intenta formato "YYYY-MM-DD HH:MM"
        final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2})').firstMatch(tsStr);
        if (m != null) {
          ts = DateTime(
            int.parse(m.group(1)!),
            int.parse(m.group(2)!),
            int.parse(m.group(3)!),
            int.parse(m.group(4)!),
            int.parse(m.group(5)!),
          );
        }
      }

      out.add(_CsvSaleRow(
        ts: ts,
        amount: amount,
        method: methodStr.isEmpty ? "Efectivo" : methodStr,
        type: typeStr.isEmpty ? "Import" : typeStr,
      ));
    }

    return out;
  }
}

class _CsvSaleRow {
  final DateTime ts;
  final double amount;
  final String method;
  final String type;
  _CsvSaleRow({
    required this.ts,
    required this.amount,
    required this.method,
    required this.type,
  });
}

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("Formato CSV recomendado", style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 6),
            Text(
              "ts,amount,method,type\n"
              "2026-01-09 07:45,100,Efectivo,Rápida\n"
              "2026-01-09T08:10:00,50,Card,Manual\n\n"
              "Separador soportado: coma (,) o punto y coma (;)\n"
              "Si el CSV tiene header, se detecta y se ignora.",
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
