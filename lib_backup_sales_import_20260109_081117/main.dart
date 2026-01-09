import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/state/models.dart';
import 'app/screens/inventory_screen.dart';
import 'app/screens/settings_screen.dart';
import 'app/screens/sales_screen.dart';
import 'app/theme/rauli_theme.dart';

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

  // ===== Config global
  String tenantName = "Sucursal Principal";
  String branchName = "Sucursal Principal";
  String locale = "es_US";
  String currencyCode = "USD";
  String decimalSep = ".";
  String thousandSep = ",";
  bool taxEnabled = false;
  double taxRate = 0.0;
  String taxMode = "inclusive";

  // ===== Tema
  ThemeScheme themeScheme = ThemeScheme.rauliBlueGold;

  // ===== Ventas
  final List<Map<String, dynamic>> sales = [];

  // ===== Inventario
  final List<InventoryItem> inventoryItems = [];
  final List<StockMove> stockMoves = [];

  void _loadAll() {
    tenantName = (box.get("tenantName") ?? tenantName).toString();
    branchName = (box.get("branchName") ?? branchName).toString();
    locale = (box.get("locale") ?? locale).toString();
    currencyCode = (box.get("currencyCode") ?? currencyCode).toString();
    decimalSep = (box.get("decimalSep") ?? decimalSep).toString();
    thousandSep = (box.get("thousandSep") ?? thousandSep).toString();
    taxEnabled = (box.get("taxEnabled") ?? taxEnabled) == true;
    taxRate = ((box.get("taxRate") ?? taxRate) as num).toDouble();
    taxMode = (box.get("taxMode") ?? taxMode).toString();

    final themeRaw = (box.get("themeScheme") ?? ThemeScheme.rauliBlueGold.name).toString();
    themeScheme = ThemeScheme.values.firstWhere(
      (e) => e.name == themeRaw,
      orElse: () => ThemeScheme.rauliBlueGold,
    );

    final rawSales = box.get("sales");
    final ls = (rawSales is List) ? rawSales.cast<dynamic>() : <dynamic>[];
    sales
      ..clear()
      ..addAll(ls.whereType<Map>().map((m) => Map<String, dynamic>.from(m)));

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
    box.put("tenantName", tenantName);
    box.put("branchName", branchName);
    box.put("locale", locale);
    box.put("currencyCode", currencyCode);
    box.put("decimalSep", decimalSep);
    box.put("thousandSep", thousandSep);
    box.put("taxEnabled", taxEnabled);
    box.put("taxRate", taxRate);
    box.put("taxMode", taxMode);

    box.put("themeScheme", themeScheme.name);

    box.put("sales", sales);
    box.put("inventory_items", inventoryItems.map((i) => i.toMap()).toList());
    box.put("stock_moves", stockMoves.map((m) => m.toMap()).toList());
  }

  void setConfig({
    required String tenantName,
    required String branchName,
    required String locale,
    required String currencyCode,
    required String decimalSep,
    required String thousandSep,
    required bool taxEnabled,
    required double taxRate,
    required String taxMode,
  }) {
    this.tenantName = tenantName;
    this.branchName = branchName;
    this.locale = locale;
    this.currencyCode = currencyCode;
    this.decimalSep = decimalSep;
    this.thousandSep = thousandSep;
    this.taxEnabled = taxEnabled;
    this.taxRate = taxRate;
    this.taxMode = taxMode;
    _persistAll();
    notifyListeners();
  }

  void setThemeScheme(ThemeScheme scheme) {
    themeScheme = scheme;
    _persistAll();
    notifyListeners();
  }

  // ===== Ventas
  void addSale({required double amount, String method = "Efectivo", String type = "Manual"}) {
    addSaleAt(ts: DateTime.now(), amount: amount, method: method, type: type);
  }

  void addSaleAt({
    required DateTime ts,
    required double amount,
    String method = "Efectivo",
    String type = "Import",
  }) {
    sales.insert(0, {
      "id": "s_${DateTime.now().millisecondsSinceEpoch}",
      "ts": ts.toIso8601String(),
      "amount": amount,
      "method": method,
      "type": type,
    });
    _persistAll();
    notifyListeners();
  }

  void addQuickSale({required double amount, String method = "Efectivo"}) {
    addSale(amount: amount, method: method, type: "Rápida");
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

  // ===== Inventario
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
      if (m.type == MoveType.adjust) stock = m.qty;
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

  void syncNow() {
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
    final state = AppStateScope.of(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "RAULI",
      theme: RauliTheme.build(state.themeScheme),
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
      const SalesScreenPro(),
      const _ProductionScreen(),
      const InventoryScreenPro(),
      const SettingsScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("RAULI – Negocio"),
        actions: [
          IconButton(
            tooltip: "IA (próximo)",
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("IA RAULI: voz + soporte + tickets (próximo).")),
              );
            },
            icon: const Icon(Icons.mic_rounded),
          ),
          IconButton(
            tooltip: "Actualizar / Sincronizar",
            onPressed: () {
              state.syncNow();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Actualización ejecutada (offline).")),
              );
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: "Configuración",
            onPressed: () => setState(() => index = 4),
            icon: const Icon(Icons.settings_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: pages[index],
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
          const NavigationDestination(icon: Icon(Icons.settings_rounded), label: "Config"),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Dashboard",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                            "${state.branchName} • Offline-First • ${state.currencyCode}",
                            style: const TextStyle(color: Colors.black54),
                          ),
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
                _StatCard(
                  title: "Ventas Hoy",
                  value: "\$ ${state.todaySalesTotal.toStringAsFixed(2)}",
                  icon: Icons.attach_money_rounded,
                ),
                _StatCard(
                  title: "Órdenes",
                  value: "${state.todayOrdersCount}",
                  icon: Icons.receipt_long_rounded,
                ),
                _StatCard(
                  title: "Caja",
                  value: "\$ ${state.todaySalesTotal.toStringAsFixed(2)}",
                  icon: Icons.account_balance_wallet_rounded,
                ),
                _StatCard(
                  title: "Inventario",
                  value: state.hasLowStock ? "LOW" : "OK",
                  icon: Icons.inventory_2_rounded,
                ),
              ],
            ),

            const SizedBox(height: 14),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text("Acciones", style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: onQuickSale,
                        icon: const Icon(Icons.flash_on_rounded),
                        label: const Text("Venta rápida \$100"),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Venta por productos: próximo.")),
                          );
                        },
                        icon: const Icon(Icons.shopping_cart_checkout_rounded),
                        label: const Text("Venta por productos"),
                      ),
                    ],
                  ),
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
    final scheme = Theme.of(context).colorScheme;
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
                  color: scheme.secondary.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: scheme.tertiary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
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
