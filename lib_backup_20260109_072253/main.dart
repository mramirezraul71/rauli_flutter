import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'theme/rauli_theme.dart';

late Box rauliBox; // ✅ Caja global Hive

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  rauliBox = await Hive.openBox('rauli');

  // ✅ Captura mínima de errores de Flutter y los guarda como reporte automático
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _logAutoError(details);
  };

  // ✅ Captura errores asincrónicos (best-effort)
  runZonedGuarded(() {
    runApp(RauliApp(box: rauliBox));
  }, (error, stack) {
    _logAutoErrorRaw(error, stack);
  });
}

/// ===============================
/// REPORTES (Incidencias / Feedback)
/// ===============================
enum ReportType { bug, suggestion, feedback, autoError }
enum ReportSeverity { p0, p1, p2, p3 }
enum ReportStatus { queued, sent, resolved }

extension ReportTypeLabel on ReportType {
  String get label {
    switch (this) {
      case ReportType.bug:
        return "Error (Bug)";
      case ReportType.suggestion:
        return "Sugerencia";
      case ReportType.feedback:
        return "Feedback";
      case ReportType.autoError:
        return "Auto Error";
    }
  }
}

extension ReportSeverityLabel on ReportSeverity {
  String get label {
    switch (this) {
      case ReportSeverity.p0:
        return "P0 Crítico";
      case ReportSeverity.p1:
        return "P1 Alto";
      case ReportSeverity.p2:
        return "P2 Medio";
      case ReportSeverity.p3:
        return "P3 Bajo";
    }
  }
}

extension ReportStatusLabel on ReportStatus {
  String get label {
    switch (this) {
      case ReportStatus.queued:
        return "Pendiente";
      case ReportStatus.sent:
        return "Enviado";
      case ReportStatus.resolved:
        return "Resuelto";
    }
  }
}

class ReportItem {
  final String id;
  final DateTime ts;
  final ReportType type;
  final ReportSeverity severity;
  final ReportStatus status;

  // Contexto
  final String module; // pantalla/módulo
  final String title;
  final String description;

  // Device/App info (mínimo)
  final String appVersion;
  final String platform;

  const ReportItem({
    required this.id,
    required this.ts,
    required this.type,
    required this.severity,
    required this.status,
    required this.module,
    required this.title,
    required this.description,
    required this.appVersion,
    required this.platform,
  });

  Map<String, dynamic> toMap() => {
        "id": id,
        "ts": ts.toIso8601String(),
        "type": type.name,
        "severity": severity.name,
        "status": status.name,
        "module": module,
        "title": title,
        "description": description,
        "appVersion": appVersion,
        "platform": platform,
      };

  static ReportItem fromMap(Map m) {
    ReportType type = ReportType.feedback;
    final t = (m["type"] ?? "feedback").toString();
    if (t == "bug") type = ReportType.bug;
    if (t == "suggestion") type = ReportType.suggestion;
    if (t == "autoError") type = ReportType.autoError;

    ReportSeverity sev = ReportSeverity.p3;
    final s = (m["severity"] ?? "p3").toString();
    if (s == "p0") sev = ReportSeverity.p0;
    if (s == "p1") sev = ReportSeverity.p1;
    if (s == "p2") sev = ReportSeverity.p2;

    ReportStatus st = ReportStatus.queued;
    final stRaw = (m["status"] ?? "queued").toString();
    if (stRaw == "sent") st = ReportStatus.sent;
    if (stRaw == "resolved") st = ReportStatus.resolved;

    return ReportItem(
      id: (m["id"] ?? "").toString(),
      ts: DateTime.tryParse((m["ts"] ?? "").toString()) ?? DateTime.now(),
      type: type,
      severity: sev,
      status: st,
      module: (m["module"] ?? "Desconocido").toString(),
      title: (m["title"] ?? "").toString(),
      description: (m["description"] ?? "").toString(),
      appVersion: (m["appVersion"] ?? "1.0.0").toString(),
      platform: (m["platform"] ?? "windows").toString(),
    );
  }

  ReportItem copyWith({ReportStatus? status}) {
    return ReportItem(
      id: id,
      ts: ts,
      type: type,
      severity: severity,
      status: status ?? this.status,
      module: module,
      title: title,
      description: description,
      appVersion: appVersion,
      platform: platform,
    );
  }
}

void _logAutoError(FlutterErrorDetails details) {
  final error = details.exceptionAsString();
  final stack = details.stack?.toString() ?? "";
  _logAutoErrorRaw(error, stack);
}

void _logAutoErrorRaw(Object error, Object? stack) {
  try {
    final now = DateTime.now();
    final id = "r_${now.millisecondsSinceEpoch}";
    final item = ReportItem(
      id: id,
      ts: now,
      type: ReportType.autoError,
      severity: ReportSeverity.p2,
      status: ReportStatus.queued,
      module: "AutoError",
      title: "Error automático capturado",
      description: "Error: $error\n\nStack:\n$stack",
      appVersion: "1.0.0",
      platform: "windows",
    );

    final raw = rauliBox.get("reports");
    final list = (raw is List) ? raw.cast<dynamic>() : <dynamic>[];
    list.add(item.toMap());
    rauliBox.put("reports", list);
  } catch (_) {
    // no rompemos la app
  }
}

/// ===============================
/// CONFIG GLOBAL (defaults + presets)
/// ===============================
enum TaxMode { included, excluded }

extension TaxModeLabel on TaxMode {
  String get label => this == TaxMode.included ? "Incluido" : "Agregado";
}

class RauliConfig {
  final String locale;
  final String currencyCode;
  final String currencySymbol;
  final String decimalSep;
  final String thousandSep;
  final bool taxEnabled;
  final double taxRate;
  final TaxMode taxMode;

  const RauliConfig({
    required this.locale,
    required this.currencyCode,
    required this.currencySymbol,
    required this.decimalSep,
    required this.thousandSep,
    required this.taxEnabled,
    required this.taxRate,
    required this.taxMode,
  });

  static const defaults = RauliConfig(
    locale: "es_US",
    currencyCode: "USD",
    currencySymbol: "\$",
    decimalSep: ".",
    thousandSep: ",",
    taxEnabled: false,
    taxRate: 0.0,
    taxMode: TaxMode.excluded,
  );

  static const presetUSRetail = RauliConfig(
    locale: "en_US",
    currencyCode: "USD",
    currencySymbol: "\$",
    decimalSep: ".",
    thousandSep: ",",
    taxEnabled: true,
    taxRate: 0.07,
    taxMode: TaxMode.excluded,
  );

  static const presetLATAM_IVA = RauliConfig(
    locale: "es_MX",
    currencyCode: "MXN",
    currencySymbol: "\$",
    decimalSep: ".",
    thousandSep: ",",
    taxEnabled: true,
    taxRate: 0.16,
    taxMode: TaxMode.included,
  );

  static const presetRD_ITBIS = RauliConfig(
    locale: "es_DO",
    currencyCode: "DOP",
    currencySymbol: "RD\$",
    decimalSep: ".",
    thousandSep: ",",
    taxEnabled: true,
    taxRate: 0.18,
    taxMode: TaxMode.included,
  );

  static const presetEU_VAT = RauliConfig(
    locale: "en_US",
    currencyCode: "EUR",
    currencySymbol: "€",
    decimalSep: ".",
    thousandSep: ",",
    taxEnabled: true,
    taxRate: 0.20,
    taxMode: TaxMode.included,
  );

  static List<_Preset> presets() => const [
        _Preset("Global (Default)", defaults),
        _Preset("US Retail (Sales Tax)", presetUSRetail),
        _Preset("LATAM IVA (Incluido)", presetLATAM_IVA),
        _Preset("Rep. Dom. ITBIS (Incluido)", presetRD_ITBIS),
        _Preset("EU VAT (Incluido)", presetEU_VAT),
      ];

  Map<String, dynamic> toMap() => {
        "locale": locale,
        "currencyCode": currencyCode,
        "currencySymbol": currencySymbol,
        "decimalSep": decimalSep,
        "thousandSep": thousandSep,
        "taxEnabled": taxEnabled,
        "taxRate": taxRate,
        "taxMode": taxMode.name,
      };

  static RauliConfig fromMap(Map m) {
    TaxMode mode = TaxMode.excluded;
    final rawMode = (m["taxMode"] ?? "excluded").toString();
    if (rawMode == "included") mode = TaxMode.included;

    return RauliConfig(
      locale: (m["locale"] ?? defaults.locale).toString(),
      currencyCode: (m["currencyCode"] ?? defaults.currencyCode).toString(),
      currencySymbol: (m["currencySymbol"] ?? defaults.currencySymbol).toString(),
      decimalSep: (m["decimalSep"] ?? defaults.decimalSep).toString(),
      thousandSep: (m["thousandSep"] ?? defaults.thousandSep).toString(),
      taxEnabled: (m["taxEnabled"] ?? defaults.taxEnabled) == true,
      taxRate: ((m["taxRate"] ?? defaults.taxRate) as num).toDouble(),
      taxMode: mode,
    );
  }
}

class _Preset {
  final String name;
  final RauliConfig config;
  const _Preset(this.name, this.config);
}

String formatMoney(double value, RauliConfig c) {
  final negative = value < 0;
  final v = value.abs();

  final fixed = v.toStringAsFixed(2);
  final parts = fixed.split(".");
  final intPart = parts[0];
  final decPart = parts.length > 1 ? parts[1] : "00";

  final sb = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    sb.write(intPart[i]);
    final remaining = intPart.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) sb.write(c.thousandSep);
  }

  final out = "${sb.toString()}${c.decimalSep}$decPart";
  return "${negative ? "-" : ""}${c.currencySymbol} $out";
}

double applyTax(double subtotal, RauliConfig c) {
  if (!c.taxEnabled || c.taxRate <= 0) return subtotal;
  if (c.taxMode == TaxMode.included) return subtotal;
  return subtotal * (1 + c.taxRate);
}

/// ===============================
/// DATA MODELS (con persistencia map)
/// ===============================
class Product {
  final String id;
  final String name;
  final double price;

  Product({required this.id, required this.name, required this.price});

  Map<String, dynamic> toMap() => {
        "id": id,
        "name": name,
        "price": price,
      };

  static Product fromMap(Map m) => Product(
        id: (m["id"] ?? "").toString(),
        name: (m["name"] ?? "").toString(),
        price: ((m["price"] ?? 0) as num).toDouble(),
      );
}

enum PaymentType { efectivo, tarjeta, transferencia, otro }

extension PaymentTypeLabel on PaymentType {
  String get label {
    switch (this) {
      case PaymentType.efectivo:
        return "Efectivo";
      case PaymentType.tarjeta:
        return "Tarjeta";
      case PaymentType.transferencia:
        return "Transferencia";
      case PaymentType.otro:
        return "Otro";
    }
  }
}

enum SalesMode { productos, rapida }

class SaleItem {
  final String productId;
  final String name;
  final int qty;
  final double price;

  SaleItem({
    required this.productId,
    required this.name,
    required this.qty,
    required this.price,
  });

  double get subtotal => qty * price;

  Map<String, dynamic> toMap() => {
        "productId": productId,
        "name": name,
        "qty": qty,
        "price": price,
      };

  static SaleItem fromMap(Map m) => SaleItem(
        productId: (m["productId"] ?? "").toString(),
        name: (m["name"] ?? "").toString(),
        qty: (m["qty"] ?? 0) as int,
        price: ((m["price"] ?? 0) as num).toDouble(),
      );
}

class Sale {
  final String id;
  final DateTime ts;
  final PaymentType payment;
  final List<SaleItem> items;
  final SalesMode mode;

  Sale({
    required this.id,
    required this.ts,
    required this.payment,
    required this.items,
    required this.mode,
  });

  double subtotal() => items.fold(0.0, (sum, i) => sum + i.subtotal);

  double totalWithTax(RauliConfig c) => applyTax(subtotal(), c);

  String get modeLabel {
    final base = mode == SalesMode.productos ? "Productos" : "Rápida";
    return "$base • ${payment.label}";
  }

  Map<String, dynamic> toMap() => {
        "id": id,
        "ts": ts.toIso8601String(),
        "payment": payment.name,
        "mode": mode.name,
        "items": items.map((i) => i.toMap()).toList(),
      };

  static Sale fromMap(Map m) {
    PaymentType pay = PaymentType.efectivo;
    final p = (m["payment"] ?? "efectivo").toString();
    if (p == "tarjeta") pay = PaymentType.tarjeta;
    if (p == "transferencia") pay = PaymentType.transferencia;
    if (p == "otro") pay = PaymentType.otro;

    SalesMode mode = SalesMode.productos;
    final mo = (m["mode"] ?? "productos").toString();
    if (mo == "rapida") mode = SalesMode.rapida;

    final rawItems =
        (m["items"] is List) ? (m["items"] as List).cast<dynamic>() : <dynamic>[];
    final items = rawItems.whereType<Map>().map(SaleItem.fromMap).toList();

    return Sale(
      id: (m["id"] ?? "").toString(),
      ts: DateTime.tryParse((m["ts"] ?? "").toString()) ?? DateTime.now(),
      payment: pay,
      items: items,
      mode: mode,
    );
  }
}

/// ===============================
/// APP STATE (offline + config + reportes + ventas/productos persistidos)
/// ===============================
class AppState extends ChangeNotifier {
  final Box box;

  AppState({required this.box}) {
    _loadConfig();
    _loadReports();
    _loadProducts();
    _loadSales();
  }

  // ===== Config
  RauliConfig config = RauliConfig.defaults;

  void _loadConfig() {
    final raw = box.get("config");
    if (raw is Map) {
      config = RauliConfig.fromMap(raw);
    } else {
      config = RauliConfig.defaults;
      box.put("config", config.toMap());
    }
  }

  void setConfig(RauliConfig c) {
    config = c;
    box.put("config", config.toMap());
    notifyListeners();
  }

  // ===== Reportes
  final List<ReportItem> reports = [];

  void _loadReports() {
    final raw = box.get("reports");
    final list = (raw is List) ? raw.cast<dynamic>() : <dynamic>[];
    reports
      ..clear()
      ..addAll(list.whereType<Map>().map(ReportItem.fromMap));
  }

  void _persistReports() {
    box.put("reports", reports.map((r) => r.toMap()).toList());
  }

  void addReport(ReportItem item) {
    reports.add(item);
    _persistReports();
    notifyListeners();
  }

  void markReportSent(String id) {
    final idx = reports.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    reports[idx] = reports[idx].copyWith(status: ReportStatus.sent);
    _persistReports();
    notifyListeners();
  }

  // ===== Productos (persistidos)
  final List<Product> products = [];

  List<Product> _defaultProducts() => [
        Product(id: "p1", name: "Producto A", price: 1.00),
        Product(id: "p2", name: "Producto B", price: 0.75),
        Product(id: "p3", name: "Producto C", price: 1.25),
        Product(id: "p4", name: "Producto D", price: 3.50),
      ];

  void _loadProducts() {
    final raw = box.get("products");
    final list = (raw is List) ? raw.cast<dynamic>() : <dynamic>[];

    products.clear();

    if (list.isEmpty) {
      products.addAll(_defaultProducts());
      _persistProducts();
      return;
    }

    products.addAll(list.whereType<Map>().map(Product.fromMap));

    if (products.isEmpty) {
      products.addAll(_defaultProducts());
      _persistProducts();
    }
  }

  void _persistProducts() {
    box.put("products", products.map((p) => p.toMap()).toList());
  }

  void addProduct(String name, double price) {
    final id =
        "p${products.length + 1}_${DateTime.now().millisecondsSinceEpoch}";
    products.add(Product(id: id, name: name, price: price));
    _persistProducts();
    notifyListeners();
  }

  // ===== Ventas (persistidas)
  final List<Sale> sales = [];

  void _loadSales() {
    final raw = box.get("sales");
    final list = (raw is List) ? raw.cast<dynamic>() : <dynamic>[];
    sales
      ..clear()
      ..addAll(list.whereType<Map>().map(Sale.fromMap));
  }

  void _persistSales() {
    box.put("sales", sales.map((s) => s.toMap()).toList());
  }

  void addSale(Sale sale) {
    sales.add(sale);
    _persistSales();
    notifyListeners();
  }

  // ===== KPIs
  DateTime _startOfDay(DateTime t) => DateTime(t.year, t.month, t.day);
  DateTime _endOfDay(DateTime t) =>
      DateTime(t.year, t.month, t.day, 23, 59, 59);

  List<Sale> salesToday() {
    final now = DateTime.now();
    final a = _startOfDay(now);
    final b = _endOfDay(now);
    return sales.where((s) => !s.ts.isBefore(a) && !s.ts.isAfter(b)).toList();
  }

  double salesTotalToday() =>
      salesToday().fold(0.0, (sum, s) => sum + s.totalWithTax(config));
  int ordersToday() => salesToday().length;
  double cashToday() => salesTotalToday();
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static AppState of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    if (scope?.notifier == null) throw Exception("AppStateScope no encontrado");
    return scope!.notifier!;
  }
}

/// ===============================
/// APP
/// ===============================
class RauliApp extends StatelessWidget {
  final Box box;
  const RauliApp({super.key, required this.box});

  @override
  Widget build(BuildContext context) {
    final state = AppState(box: box);

    return AppStateScope(
      notifier: state,
      child: MaterialApp(
        title: 'RAULI',
        debugShowCheckedModeBanner: true,
        theme: RauliTheme.light(),
        home: const AppShell(),
      ),
    );
  }
}

/// ===============================
/// APP SHELL
/// ===============================
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;

  String tenantName = "RAULI – Negocio";
  String branchName = "Sucursal Principal";

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(branchName: branchName, onQuickUpdate: _fakeSyncNow),
      const SalesScreen(),
      const ProductionScreen(),
      const InventoryScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(tenantName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          // 🎤 IA por Voz (demo UI)
          IconButton(
            tooltip: "Hablar con IA",
            icon: const Icon(Icons.mic_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const _VoiceAIDialog(),
              );
            },
          ),

          // 🤖 Soporte IA / Reportar
          IconButton(
            tooltip: "Soporte IA / Reportar",
            icon: const Icon(Icons.support_agent_rounded),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SupportCenterScreen(
                    tenantName: tenantName,
                    branchName: branchName,
                  ),
                ),
              );
            },
          ),

          IconButton(
            tooltip: "Actualizar / Sincronizar",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fakeSyncNow,
          ),
          IconButton(
            tooltip: "Configuración Global",
            icon: const Icon(Icons.settings_rounded),
            onPressed: () async {
              final result = await showDialog<_SettingsResult>(
                context: context,
                builder: (_) => SettingsDialog(
                  tenantName: tenantName,
                  branchName: branchName,
                ),
              );
              if (result != null) {
                setState(() {
                  tenantName = result.tenantName;
                  branchName = result.branchName;
                });
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: IndexedStack(index: index, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_rounded), label: "Dashboard"),
          NavigationDestination(
              icon: Icon(Icons.point_of_sale_rounded), label: "Ventas"),
          NavigationDestination(
              icon: Icon(Icons.factory_rounded), label: "Producción"),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_rounded), label: "Inventario"),
        ],
      ),
    );
  }

  void _fakeSyncNow() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: const Text("RAULI: actualización/sincronización (demo)."),
        action: SnackBarAction(label: "OK", onPressed: () {}),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// ===============================
/// DASHBOARD
/// ===============================
class DashboardScreen extends StatelessWidget {
  final String branchName;
  final VoidCallback onQuickUpdate;

  const DashboardScreen({
    super.key,
    required this.branchName,
    required this.onQuickUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final c = state.config;

    final kpi = <_Kpi>[
      _Kpi("Ventas Hoy", formatMoney(state.salesTotalToday(), c),
          Icons.attach_money_rounded),
      _Kpi("Órdenes", "${state.ordersToday()}", Icons.receipt_long_rounded),
      _Kpi("Caja", formatMoney(state.cashToday(), c),
          Icons.account_balance_wallet_rounded),
      _Kpi("Inventario", "OK", Icons.inventory_2_rounded),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderTile(
            title: "Dashboard",
            subtitle: "$branchName • Offline-First • ${c.currencyCode}",
            rightActionText: "Actualizar",
            onRightAction: onQuickUpdate,
          ),
          const SizedBox(height: 12),
          _KpiGrid(items: kpi),
          const SizedBox(height: 12),
          _RecentSalesCard(),
          const SizedBox(height: 12),
          const _InfoBanner(
            title: "IA RAULI (próximo)",
            message:
                "Después del POS: alertas de margen, errores y recomendaciones de inventario.",
            icon: Icons.smart_toy_rounded,
          ),
        ],
      ),
    );
  }
}

class _RecentSalesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final c = state.config;
    final today = state.salesToday()..sort((a, b) => b.ts.compareTo(a.ts));

    if (today.isEmpty) {
      return const _EmptyState(
        title: "Aún no hay movimientos",
        subtitle:
            "Registra una venta y RAULI mostrará aquí el historial del día.",
        icon: Icons.timeline_rounded,
      );
    }

    final top = today.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Últimas ventas (hoy)",
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            for (final s in top) ...[
              Row(
                children: [
                  Expanded(
                    child: Text("${_fmtTime(s.ts)} • ${s.modeLabel}",
                        style: const TextStyle(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text(formatMoney(s.totalWithTax(c), c),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 6),
            ]
          ],
        ),
      ),
    );
  }

  static String _fmtTime(DateTime t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
}

class _Kpi {
  final String label;
  final String value;
  final IconData icon;
  _Kpi(this.label, this.value, this.icon);
}

class _KpiGrid extends StatelessWidget {
  final List<_Kpi> items;
  const _KpiGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final isWide = c.maxWidth >= 720;
      final crossAxisCount = isWide ? 4 : 2;

      return GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.2,
        ),
        itemBuilder: (_, i) => _KpiCard(item: items[i]),
      );
    });
  }
}

class _KpiCard extends StatelessWidget {
  final _Kpi item;
  const _KpiCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .secondary
                    .withOpacity(0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(item.value,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// VENTAS
/// ===============================
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  SalesMode mode = SalesMode.productos;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ventas",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded),
                    const SizedBox(width: 10),
                    const Text("Modo:",
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(width: 12),
                    ToggleButtons(
                      isSelected: [
                        mode == SalesMode.productos,
                        mode == SalesMode.rapida
                      ],
                      onPressed: (i) => setState(() =>
                          mode = i == 0 ? SalesMode.productos : SalesMode.rapida),
                      borderRadius: BorderRadius.circular(12),
                      children: const [
                        Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Text("Por productos")),
                        Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Text("Venta rápida")),
                      ],
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await showDialog(
                            context: context,
                            builder: (_) => const AddProductDialog());
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text("Producto"),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (mode == SalesMode.productos) const SalesByProductsCard(),
            if (mode == SalesMode.rapida) const QuickSaleCard(),
          ],
        ),
      ),
    );
  }
}

class SalesByProductsCard extends StatefulWidget {
  const SalesByProductsCard({super.key});

  @override
  State<SalesByProductsCard> createState() => _SalesByProductsCardState();
}

class _SalesByProductsCardState extends State<SalesByProductsCard> {
  final Map<String, int> qtyByProductId = {};
  PaymentType pay = PaymentType.efectivo;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final c = state.config;

    double subtotal = 0;
    for (final p in state.products) {
      final q = qtyByProductId[p.id] ?? 0;
      subtotal += q * p.price;
    }

    final total = applyTax(subtotal, c);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Venta por productos • ${c.taxEnabled ? "Impuesto ${c.taxMode.label}" : "Sin impuesto"}",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _PaymentRow(value: pay, onChanged: (v) => setState(() => pay = v)),
            const SizedBox(height: 10),
            const Text("Productos", style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            for (final p in state.products)
              _ProductLine(
                product: p,
                qty: qtyByProductId[p.id] ?? 0,
                onAdd: () => setState(() =>
                    qtyByProductId[p.id] = (qtyByProductId[p.id] ?? 0) + 1),
                onRemove: () => setState(() {
                  final current = qtyByProductId[p.id] ?? 0;
                  if (current <= 1) {
                    qtyByProductId.remove(p.id);
                  } else {
                    qtyByProductId[p.id] = current - 1;
                  }
                }),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("Subtotal: ${formatMoney(subtotal, c)}",
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text("Total: ${formatMoney(total, c)}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  ]),
                ),
                TextButton(onPressed: () => setState(qtyByProductId.clear), child: const Text("Limpiar")),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: total <= 0
                      ? null
                      : () {
                          final items = <SaleItem>[];
                          for (final p in state.products) {
                            final q = qtyByProductId[p.id] ?? 0;
                            if (q > 0) {
                              items.add(SaleItem(productId: p.id, name: p.name, qty: q, price: p.price));
                            }
                          }

                          final sale = Sale(
                            id: "s_${DateTime.now().millisecondsSinceEpoch}",
                            ts: DateTime.now(),
                            payment: pay,
                            items: items,
                            mode: SalesMode.productos,
                          );

                          state.addSale(sale);
                          setState(qtyByProductId.clear);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Venta registrada: ${formatMoney(sale.totalWithTax(c), c)}")),
                          );
                        },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text("Cobrar"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _ProductLine extends StatelessWidget {
  final Product product;
  final int qty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductLine({
    required this.product,
    required this.qty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppStateScope.of(context).config;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "${product.name}  •  ${formatMoney(product.price, c)}",
              style: const TextStyle(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
              onPressed: qty > 0 ? onRemove : null,
              icon: const Icon(Icons.remove_circle_outline_rounded)),
          SizedBox(
              width: 28,
              child: Text("$qty",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w900))),
          IconButton(onPressed: onAdd, icon: const Icon(Icons.add_circle_outline_rounded)),
        ],
      ),
    );
  }
}

class QuickSaleCard extends StatefulWidget {
  const QuickSaleCard({super.key});

  @override
  State<QuickSaleCard> createState() => _QuickSaleCardState();
}

class _QuickSaleCardState extends State<QuickSaleCard> {
  final amountCtrl = TextEditingController();
  final noteCtrl = TextEditingController();
  PaymentType pay = PaymentType.efectivo;

  @override
  void dispose() {
    amountCtrl.dispose();
    noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final c = state.config;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Venta rápida • ${c.taxEnabled ? "Impuesto ${c.taxMode.label}" : "Sin impuesto"}",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 10),
            _PaymentRow(value: pay, onChanged: (v) => setState(() => pay = v)),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Monto (subtotal)",
                prefixIcon: Icon(Icons.attach_money_rounded),
                hintText: "Ej: 12.50",
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
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    final raw = amountCtrl.text.trim().replaceAll(',', '.');
                    final subtotal = double.tryParse(raw) ?? 0;
                    if (subtotal <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Monto inválido.")));
                      return;
                    }

                    final itemName = noteCtrl.text.trim().isEmpty
                        ? "Venta rápida"
                        : noteCtrl.text.trim();

                    final sale = Sale(
                      id: "s_${DateTime.now().millisecondsSinceEpoch}",
                      ts: DateTime.now(),
                      payment: pay,
                      items: [
                        SaleItem(
                            productId: "quick",
                            name: itemName,
                            qty: 1,
                            price: subtotal)
                      ],
                      mode: SalesMode.rapida,
                    );

                    state.addSale(sale);

                    amountCtrl.clear();
                    noteCtrl.clear();

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              "Venta registrada: ${formatMoney(sale.totalWithTax(c), c)}")),
                    );
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text("Registrar"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final PaymentType value;
  final ValueChanged<PaymentType> onChanged;

  const _PaymentRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.payments_rounded),
        const SizedBox(width: 10),
        const Text("Pago:", style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        DropdownButton<PaymentType>(
          value: value,
          onChanged: (v) => onChanged(v ?? PaymentType.efectivo),
          items: PaymentType.values
              .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
              .toList(),
        ),
      ],
    );
  }
}

class AddProductDialog extends StatefulWidget {
  const AddProductDialog({super.key});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> {
  final nameCtrl = TextEditingController();
  final priceCtrl = TextEditingController();

  @override
  void dispose() {
    nameCtrl.dispose();
    priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AlertDialog(
      title: const Text("Agregar producto"),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                  labelText: "Nombre", prefixIcon: Icon(Icons.local_mall_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: "Precio",
                  prefixIcon: Icon(Icons.attach_money_rounded),
                  hintText: "Ej: 2.50"),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar")),
        FilledButton(
          onPressed: () {
            final name = nameCtrl.text.trim();
            final raw = priceCtrl.text.trim().replaceAll(',', '.');
            final price = double.tryParse(raw) ?? 0;

            if (name.isEmpty || price <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Nombre o precio inválido.")));
              return;
            }

            state.addProduct(name, price);
            Navigator.pop(context);
          },
          child: const Text("Guardar"),
        ),
      ],
    );
  }
}

/// ===============================
/// SOPORTE (Reportar + Mis reportes)
/// ===============================
class SupportCenterScreen extends StatefulWidget {
  final String tenantName;
  final String branchName;

  const SupportCenterScreen({
    super.key,
    required this.tenantName,
    required this.branchName,
  });

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  ReportType type = ReportType.bug;
  ReportSeverity severity = ReportSeverity.p2;

  final moduleCtrl = TextEditingController(text: "Dashboard");
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();

  @override
  void dispose() {
    moduleCtrl.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final reports = [...state.reports]..sort((a, b) => b.ts.compareTo(a.ts));

    return Scaffold(
      appBar: AppBar(title: const Text("Soporte IA / Reportar")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (_, c) {
          final wide = c.maxWidth >= 980;

          final form = _SupportFormCard(
            tenantName: widget.tenantName,
            branchName: widget.branchName,
            type: type,
            severity: severity,
            moduleCtrl: moduleCtrl,
            titleCtrl: titleCtrl,
            descCtrl: descCtrl,
            onTypeChanged: (v) => setState(() => type = v),
            onSeverityChanged: (v) => setState(() => severity = v),
            onSubmit: () => _submit(state),
          );

          final list = _ReportsListCard(
            reports: reports,
            onMarkSent: (id) => state.markReportSent(id),
          );

          if (!wide) {
            return ListView(
              children: [
                form,
                const SizedBox(height: 12),
                list,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: form),
              const SizedBox(width: 12),
              Expanded(child: list),
            ],
          );
        }),
      ),
    );
  }

  void _submit(AppState state) {
    final module =
        moduleCtrl.text.trim().isEmpty ? "Desconocido" : moduleCtrl.text.trim();
    final title = titleCtrl.text.trim();
    final desc = descCtrl.text.trim();

    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Completa Título y Descripción.")),
      );
      return;
    }

    final now = DateTime.now();
    final item = ReportItem(
      id: "r_${now.millisecondsSinceEpoch}",
      ts: now,
      type: type,
      severity: severity,
      status: ReportStatus.queued,
      module: module,
      title: title,
      description: desc,
      appVersion: "1.0.0",
      platform: "windows",
    );

    state.addReport(item);

    titleCtrl.clear();
    descCtrl.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Reporte creado (pendiente de enviar).")),
    );
  }
}

class _SupportFormCard extends StatelessWidget {
  final String tenantName;
  final String branchName;

  final ReportType type;
  final ReportSeverity severity;

  final TextEditingController moduleCtrl;
  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;

  final ValueChanged<ReportType> onTypeChanged;
  final ValueChanged<ReportSeverity> onSeverityChanged;
  final VoidCallback onSubmit;

  const _SupportFormCard({
    required this.tenantName,
    required this.branchName,
    required this.type,
    required this.severity,
    required this.moduleCtrl,
    required this.titleCtrl,
    required this.descCtrl,
    required this.onTypeChanged,
    required this.onSeverityChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Crear reporte",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 8),
            Text("Negocio: $tenantName • Sucursal: $branchName",
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _DropRow(
                    label: "Tipo",
                    child: DropdownButton<ReportType>(
                      value: type,
                      onChanged: (v) => onTypeChanged(v ?? type),
                      items: ReportType.values
                          .where((t) => t != ReportType.autoError)
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t.label)))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DropRow(
                    label: "Severidad",
                    child: DropdownButton<ReportSeverity>(
                      value: severity,
                      onChanged: (v) => onSeverityChanged(v ?? severity),
                      items: ReportSeverity.values
                          .map((s) => DropdownMenuItem(
                              value: s, child: Text(s.label)))
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: moduleCtrl,
              decoration: const InputDecoration(
                labelText: "Módulo / Pantalla",
                prefixIcon: Icon(Icons.view_compact_rounded),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: "Título",
                prefixIcon: Icon(Icons.title_rounded),
                hintText: "Ej: No carga la pantalla de Ventas",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "Descripción",
                prefixIcon: Icon(Icons.description_rounded),
                hintText:
                    "Describe qué pasó, qué esperabas, y pasos para reproducirlo.",
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const _InfoChip(text: "Se guarda offline (Hive)"),
                const SizedBox(width: 8),
                const _InfoChip(text: "Luego se envía a IA/Servidor"),
                const Spacer(),
                FilledButton.icon(
                  onPressed: onSubmit,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text("Crear"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsListCard extends StatelessWidget {
  final List<ReportItem> reports;
  final ValueChanged<String> onMarkSent;

  const _ReportsListCard({
    required this.reports,
    required this.onMarkSent,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptyState(
        title: "Aún no hay reportes",
        subtitle: "Cuando reportes un error o sugerencia, aparecerá aquí.",
        icon: Icons.support_agent_rounded,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Mis reportes",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 10),
            for (final r in reports.take(12)) ...[
              _ReportTile(r: r, onMarkSent: onMarkSent),
              const Divider(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final ReportItem r;
  final ValueChanged<String> onMarkSent;

  const _ReportTile({required this.r, required this.onMarkSent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Badge(text: r.severity.label),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${r.type.label} • ${r.module}",
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(r.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                r.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text("${_fmtDate(r.ts)} • Estado: ${r.status.label}",
                  style: const TextStyle(color: Colors.black45)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (r.status == ReportStatus.queued)
          FilledButton.tonal(
            onPressed: () => onMarkSent(r.id),
            child: const Text("Marcar enviado"),
          )
        else
          const Icon(Icons.check_circle_rounded),
      ],
    );
  }

  static String _fmtDate(DateTime t) {
    final y = t.year.toString().padLeft(4, '0');
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return "$y-$m-$d $hh:$mm";
  }
}

class _DropRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _DropRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
            width: 80,
            child:
                Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String text;
  const _InfoChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary.withOpacity(0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _HeaderTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String rightActionText;
  final VoidCallback onRightAction;

  const _HeaderTile({
    required this.title,
    required this.subtitle,
    required this.rightActionText,
    required this.onRightAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style:
                        const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ]),
            ),
            FilledButton.tonalIcon(
              onPressed: onRightAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(rightActionText),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

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

class _InfoBanner extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const _InfoBanner({
    required this.title,
    required this.message,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: Colors.black54)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// ===============================
/// SETTINGS (Config Global + Presets)
/// ===============================
class SettingsDialog extends StatefulWidget {
  final String tenantName;
  final String branchName;

  const SettingsDialog({
    super.key,
    required this.tenantName,
    required this.branchName,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController tenantCtrl;
  late final TextEditingController branchCtrl;

  int presetIndex = 0;
  bool taxEnabled = false;
  double taxRate = 0.0;
  TaxMode taxMode = TaxMode.excluded;

  String currencyCode = "USD";
  String currencySymbol = "\$";
  String decimalSep = ".";
  String thousandSep = ",";
  String locale = "es_US";

  bool _initializedFromState = false;

  @override
  void initState() {
    super.initState();
    tenantCtrl = TextEditingController(text: widget.tenantName);
    branchCtrl = TextEditingController(text: widget.branchName);
  }

  @override
  void dispose() {
    tenantCtrl.dispose();
    branchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final c = state.config;
    final presets = RauliConfig.presets();

    if (_initializedFromState == false) {
      _initializedFromState = true;
      taxEnabled = c.taxEnabled;
      taxRate = c.taxRate;
      taxMode = c.taxMode;
      currencyCode = c.currencyCode;
      currencySymbol = c.currencySymbol;
      decimalSep = c.decimalSep;
      thousandSep = c.thousandSep;
      locale = c.locale;

      final idx = presets.indexWhere((p) =>
          p.config.currencyCode == c.currencyCode &&
          p.config.taxEnabled == c.taxEnabled &&
          p.config.taxRate == c.taxRate &&
          p.config.taxMode == c.taxMode &&
          p.config.currencySymbol == c.currencySymbol);
      presetIndex = idx >= 0 ? idx : 0;
    }

    return AlertDialog(
      title: const Text("Configuración Global"),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: tenantCtrl,
                decoration: const InputDecoration(
                    labelText: "Negocio (Tenant)",
                    prefixIcon: Icon(Icons.store_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: branchCtrl,
                decoration: const InputDecoration(
                    labelText: "Sucursal (Branch)",
                    prefixIcon: Icon(Icons.location_on_rounded)),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.public_rounded),
                  const SizedBox(width: 10),
                  const Text("Preset:", style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(width: 10),
                  DropdownButton<int>(
                    value: presetIndex,
                    onChanged: (v) {
                      final idx = v ?? 0;
                      final pc = presets[idx].config;
                      setState(() {
                        presetIndex = idx;
                        locale = pc.locale;
                        currencyCode = pc.currencyCode;
                        currencySymbol = pc.currencySymbol;
                        decimalSep = pc.decimalSep;
                        thousandSep = pc.thousandSep;
                        taxEnabled = pc.taxEnabled;
                        taxRate = pc.taxRate;
                        taxMode = pc.taxMode;
                      });
                    },
                    items: List.generate(
                      presets.length,
                      (i) => DropdownMenuItem(value: i, child: Text(presets[i].name)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: "Región / Moneda",
                child: Column(
                  children: [
                    _RowField(
                      label: "Locale",
                      child: DropdownButton<String>(
                        value: locale,
                        onChanged: (v) => setState(() => locale = v ?? locale),
                        items: const [
                          DropdownMenuItem(value: "es_US", child: Text("es_US")),
                          DropdownMenuItem(value: "es_MX", child: Text("es_MX")),
                          DropdownMenuItem(value: "es_DO", child: Text("es_DO")),
                          DropdownMenuItem(value: "en_US", child: Text("en_US")),
                        ],
                      ),
                    ),
                    _RowField(
                      label: "Moneda",
                      child: DropdownButton<String>(
                        value: currencyCode,
                        onChanged: (v) => setState(() => currencyCode = v ?? currencyCode),
                        items: const [
                          DropdownMenuItem(value: "USD", child: Text("USD")),
                          DropdownMenuItem(value: "DOP", child: Text("DOP")),
                          DropdownMenuItem(value: "MXN", child: Text("MXN")),
                          DropdownMenuItem(value: "EUR", child: Text("EUR")),
                        ],
                      ),
                    ),
                    _RowField(
                      label: "Símbolo",
                      child: DropdownButton<String>(
                        value: currencySymbol,
                        onChanged: (v) => setState(() => currencySymbol = v ?? currencySymbol),
                        items: const [
                          DropdownMenuItem(value: "\$", child: Text("\$")),
                          DropdownMenuItem(value: "RD\$", child: Text("RD\$")),
                          DropdownMenuItem(value: "€", child: Text("€")),
                        ],
                      ),
                    ),
                    _RowField(
                      label: "Decimal",
                      child: DropdownButton<String>(
                        value: decimalSep,
                        onChanged: (v) => setState(() => decimalSep = v ?? decimalSep),
                        items: const [
                          DropdownMenuItem(value: ".", child: Text(".")),
                          DropdownMenuItem(value: ",", child: Text(",")),
                        ],
                      ),
                    ),
                    _RowField(
                      label: "Miles",
                      child: DropdownButton<String>(
                        value: thousandSep,
                        onChanged: (v) => setState(() => thousandSep = v ?? thousandSep),
                        items: const [
                          DropdownMenuItem(value: ",", child: Text(",")),
                          DropdownMenuItem(value: ".", child: Text(".")),
                          DropdownMenuItem(value: " ", child: Text("espacio")),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: "Impuestos",
                child: Column(
                  children: [
                    SwitchListTile(
                      value: taxEnabled,
                      onChanged: (v) => setState(() => taxEnabled = v),
                      title: const Text("Habilitar impuesto"),
                    ),
                    _RowField(
                      label: "Modo",
                      child: DropdownButton<TaxMode>(
                        value: taxMode,
                        onChanged: taxEnabled ? (v) => setState(() => taxMode = v ?? taxMode) : null,
                        items: TaxMode.values
                            .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                            .toList(),
                      ),
                    ),
                    _RowField(
                      label: "Tasa",
                      child: SizedBox(
                        width: 260,
                        child: Slider(
                          value: taxRate.clamp(0, 0.30),
                          onChanged: taxEnabled ? (v) => setState(() => taxRate = v) : null,
                          min: 0,
                          max: 0.30,
                          divisions: 30,
                          label: "${(taxRate * 100).toStringAsFixed(0)}%",
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Actual: ${(taxRate * 100).toStringAsFixed(0)}%",
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const _InfoBanner(
                title: "Guardado",
                message: "Esta configuración se guarda offline en Hive y aplica a todo el sistema.",
                icon: Icons.save_rounded,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
        FilledButton(
          onPressed: () {
            final newConfig = RauliConfig(
              locale: locale,
              currencyCode: currencyCode,
              currencySymbol: currencySymbol,
              decimalSep: decimalSep,
              thousandSep: thousandSep,
              taxEnabled: taxEnabled,
              taxRate: taxRate,
              taxMode: taxMode,
            );

            state.setConfig(newConfig);

            Navigator.pop(
              context,
              _SettingsResult(
                tenantName: tenantCtrl.text.trim().isEmpty ? widget.tenantName : tenantCtrl.text.trim(),
                branchName: branchCtrl.text.trim().isEmpty ? widget.branchName : branchCtrl.text.trim(),
              ),
            );
          },
          child: const Text("Guardar"),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _RowField extends StatelessWidget {
  final String label;
  final Widget child;
  const _RowField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
        const SizedBox(width: 10),
        Expanded(child: Align(alignment: Alignment.centerLeft, child: child)),
      ],
    );
  }
}

class _SettingsResult {
  final String tenantName;
  final String branchName;
  _SettingsResult({required this.tenantName, required this.branchName});
}

/// ===============================
/// PRODUCCIÓN / INVENTARIO (placeholder)
/// ===============================
class ProductionScreen extends StatelessWidget {
  const ProductionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScreen(
      title: "Producción",
      subtitle: "Aquí irá: lotes, procesos, consumo de insumos y rendimiento.",
      icon: Icons.factory_rounded,
    );
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScreen(
      title: "Inventario",
      subtitle: "Aquí irá: artículos, stock, movimientos, mínimos y alertas.",
      icon: Icons.inventory_2_rounded,
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _PlaceholderScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 46),
                  const SizedBox(height: 10),
                  Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ===============================
/// MICRÓFONO (UI DEMO)
/// ===============================
class _VoiceAIDialog extends StatelessWidget {
  const _VoiceAIDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("IA por Voz (demo)"),
      content: const SizedBox(
        width: 480,
        child: Text(
          "Aquí irá la interacción por micrófono.\n\n"
          "• Paso 1: Speech-to-Text (capturar voz)\n"
          "• Paso 2: Enviar a IA\n"
          "• Paso 3: Respuesta + acciones\n\n"
          "Por ahora es UI para confirmar que el micrófono aparece y abre el panel.",
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cerrar"),
        ),
      ],
    );
  }
}
