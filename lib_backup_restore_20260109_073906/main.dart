import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/state/models.dart';
import 'app/screens/inventory_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final box = await Hive.openBox('rauli_box');
  runApp(AppStateScope(
    notifier: AppState(box),
    child: const RauliApp(),
  ));
}

class AppState extends ChangeNotifier {
  final Box box;
  AppState(this.box) {
    _loadAll();
  }

  // ===== Ventas (demo)
  final List<Map<String, dynamic>> sales = [];

  // ===== Inventario
  final List<InventoryItem> inventoryItems = [];
  final List<StockMove> stockMoves = [];

  // ===== Config mínima (global)
  String currencyCode = "USD";

  void _loadAll() {
    // Config
    currencyCode = (box.get("currencyCode") ?? "USD").toString();

    // Sales
    final rawSales = box.get("sales");
    final ls = (rawSales is List) ? rawSales.cast<dynamic>() : <dynamic>[];
    sales
      ..clear()
      ..addAll(ls.whereType<Map>().map((m) => Map<String, dynamic>.from(m)));

    // Inventory
    final rawItems = box.get("inventory_items");
    final rawMoves = box.get("stock_moves");

    final li = (rawItems is List) ? rawItems.cast<dynamic>() : <dynamic>[];
    final lm = (rawMoves is List) ? rawMoves.cast<dynamic>() : <dynamic>[];

    inventoryItems
      ..clear()
      ..addAll(li.whereType<Map>().map(InventoryItem.fromMap));

    stockMoves
      ..clear()
      ..addAll(lm.whereType<Map>().map(StockMove.fromMap));

    notifyListeners();
  }

  void _persistAll() {
    box.put("currencyCode", currencyCode);
    box.put("sales", sales);
    box.put("inventory_items", inventoryItems.map((i) => i.toMap()).toList());
    box.put("stock_moves", stockMoves.map((m) => m.toMap()).toList());
  }

  // ===== Ventas
  void addQuickSale({required double amount, String method = "Efectivo"}) {
    sales.insert(0, {
      "id": "s_${DateTime.now().millisecondsSinceEpoch}",
      "ts": DateTime.now().toIso8601String(),
      "amount": amount,
      "method": method,
      "type": "Rapida",
    });
    _persistAll();
    notifyListeners();
  }

  double get todaySalesTotal {
    final now = DateTime.now();
    double sum = 0;
    for (final s in sales) {
      final ts = DateTime.tryParse((s["ts"] ?? "").toString());
      if (ts == null) continue;
      if (ts.year == now.year && ts.month == now.month && ts.day == now.day) {
        sum += ((s["amount"] ?? 0) as num).toDouble();
      }
    }
    return sum;
  }

  int get todayOrdersCount {
    final now = DateTime.now();
    int c = 0;
    for (final s in sales) {
      final ts = DateTime.tryParse((s["ts"] ?? "").toString());
      if (ts == null) continue;
      if (ts.year == now.year && ts.month == now.month && ts.day == now.day) c++;
    }
    return c;
  }

  // ===== Inventario API
  void addInventoryItem(InventoryItem item) {
    inventoryItems.add(item);
    _persistAll();
    notifyListeners();
  }

  void addStockMove(StockMove move) {
    stockMoves.add(move);
    _persistAll();
    notifyListeners();
  }

  double stockOf(String itemId) {
    double stock = 0.0;
    for (final m in stockMoves.where((x) => x.itemId == itemId)) {
      if (m.type == MoveType.inMove) stock += m.qty;
      if (m.type == MoveType.outMove) stock -= m.qty;
      if (m.type == MoveType.adjust) stock = m.qty; // stock “set”
    }
    return stock;
  }

  bool get hasLowStock {
    for (final it in inventoryItems) {
      if (it.stockPolicy == StockPolicy.tracked) {
        if (stockOf(it.id) < it.minStock) return true;
      }
    }
    return false;
  }

  // ===== Sync / Update (placeholder)
  void syncNow() {
    // aquí luego conectamos nube / POS / ERP
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState notifier, required Widget child})
      : super(notifier: notifier, child: child);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppStateScope>()!.notifier!;
}

class RauliApp extends StatelessWidget {
  const RauliApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: const Color(0xFF2E6BFF),
      // ✅ CardThemeData (evita el error CardTheme vs CardThemeData)
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "RAULI",
      theme: theme,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final pages = <Widget>[
      _Dashboard(onQuickSale: () => state.addQuickSale(amount: 100)),
      const _SalesScreen(),
      const _ProductionScreen(),
      const InventoryScreenPro(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("RAULI – Negocio", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          // Mic placeholder (IA)
          IconButton(
            tooltip: "IA (próximo)",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("IA RAULI: pronto (voice + soporte + tickets).")),
              );
            },
            icon: const Icon(Icons.mic_rounded),
          ),
          IconButton(
            tooltip: "Actualizar / Sincronizar",
            onPressed: () {
              state.syncNow();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Actualización ejecutada (modo offline).")),
              );
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: pages[index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: "Dashboard"),
          const NavigationDestination(icon: Icon(Icons.point_of_sale_rounded), label: "Ventas"),
          const NavigationDestination(icon: Icon(Icons.factory_rounded), label: "Producción"),
          NavigationDestination(
            icon: Stack(
              children: [
                const Icon(Icons.inventory_2_rounded),
                if (state.hasLowStock)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
              ],
            ),
            label: "Inventario",
          ),
        ],
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final VoidCallback onQuickSale;
  const _Dashboard({required this.onQuickSale});

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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Dashboard",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          SizedBox(height: 4),
                          Text("Sucursal Principal • Offline-First",
                              style: TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        state.syncNow();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Actualización ejecutada.")),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text("Actualizar"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatCard(title: "Ventas Hoy", value: "\$ ${state.todaySalesTotal.toStringAsFixed(2)}", icon: Icons.attach_money_rounded),
                _StatCard(title: "Órdenes", value: "${state.todayOrdersCount}", icon: Icons.receipt_long_rounded),
                _StatCard(title: "Caja", value: "\$ ${state.todaySalesTotal.toStringAsFixed(2)}", icon: Icons.account_balance_wallet_rounded),
                _StatCard(title: "Inventario", value: state.hasLowStock ? "LOW" : "OK", icon: Icons.inventory_2_rounded),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ActionCard(
                  title: "Venta rápida",
                  subtitle: "Registrar venta en 10 segundos",
                  icon: Icons.flash_on_rounded,
                  onTap: onQuickSale,
                ),
                _ActionCard(
                  title: "IA RAULI (próximo)",
                  subtitle: "Soporte, tickets y recomendaciones",
                  icon: Icons.smart_toy_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("IA RAULI: pronto.")),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Últimas ventas (hoy)", style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  if (state.sales.isEmpty)
                    const Text("Aún no hay movimientos", style: TextStyle(color: Colors.black54))
                  else
                    ...state.sales.take(5).map((s) {
                      final amount = ((s["amount"] ?? 0) as num).toDouble();
                      final type = (s["type"] ?? "").toString();
                      final method = (s["method"] ?? "").toString();
                      final ts = DateTime.tryParse((s["ts"] ?? "").toString());
                      final hhmm = ts == null
                          ? "--:--"
                          : "${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}";
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Text("$hhmm • $type • $method", style: const TextStyle(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            Text("\$ ${amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900)),
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
}

class _SalesScreen extends StatelessWidget {
  const _SalesScreen();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ventas", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text("Demo: aquí luego va POS completo + productos + métodos de pago.",
                          style: TextStyle(color: Colors.black54)),
                    ),
                    FilledButton(
                      onPressed: () {
                        state.addQuickSale(amount: 50, method: "Efectivo");
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Venta rápida registrada: \$50")),
                        );
                      },
                      child: const Text("Venta \$50"),
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
                    const Text("Sin ventas registradas.", style: TextStyle(color: Colors.black54))
                  else
                    ...state.sales.take(25).map((s) {
                      final amount = ((s["amount"] ?? 0) as num).toDouble();
                      final method = (s["method"] ?? "").toString();
                      final ts = DateTime.tryParse((s["ts"] ?? "").toString());
                      final when = ts == null ? "-" : ts.toLocal().toString();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text("$when • $method")),
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
}

class _ProductionScreen extends StatelessWidget {
  const _ProductionScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Producción (próximo)\nRecetas/BOM • Lotes • Consumo de inventario",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black54),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _StatCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 100,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 420,
      height: 84,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
