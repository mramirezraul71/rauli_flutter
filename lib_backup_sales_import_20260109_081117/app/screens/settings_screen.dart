import 'package:flutter/material.dart';
import '../../main.dart' show AppStateScope;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  TextEditingController? tenantCtrl;
  TextEditingController? branchCtrl;
  TextEditingController? currencyCtrl;
  TextEditingController? localeCtrl;
  TextEditingController? taxRateCtrl;

  bool taxEnabled = false;
  String decimalSep = ".";
  String thousandSep = ",";
  String taxMode = "inclusive"; // inclusive | exclusive

  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;

    final state = AppStateScope.of(context);

    tenantCtrl = TextEditingController(text: state.tenantName);
    branchCtrl = TextEditingController(text: state.branchName);
    currencyCtrl = TextEditingController(text: state.currencyCode);
    localeCtrl = TextEditingController(text: state.locale);

    taxEnabled = state.taxEnabled;
    decimalSep = state.decimalSep;
    thousandSep = state.thousandSep;
    taxMode = state.taxMode;
    taxRateCtrl = TextEditingController(text: state.taxRate.toStringAsFixed(2));

    _loaded = true;
    setState(() {});
  }

  @override
  void dispose() {
    tenantCtrl?.dispose();
    branchCtrl?.dispose();
    currencyCtrl?.dispose();
    localeCtrl?.dispose();
    taxRateCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final state = AppStateScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Configuración",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),

            _SectionCard(
              title: "Negocio y sucursal",
              child: Column(
                children: [
                  TextField(
                    controller: tenantCtrl,
                    decoration: const InputDecoration(
                      labelText: "Nombre del negocio",
                      prefixIcon: Icon(Icons.storefront_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: branchCtrl,
                    decoration: const InputDecoration(
                      labelText: "Sucursal",
                      prefixIcon: Icon(Icons.location_on_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _InfoRow(
                    icon: Icons.save_rounded,
                    text: "Se guarda offline (Hive) y aplica a todo el sistema.",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _SectionCard(
              title: "Región y moneda",
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: localeCtrl,
                          decoration: const InputDecoration(
                            labelText: "Locale (ej: es_US, en_US)",
                            prefixIcon: Icon(Icons.language_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: currencyCtrl,
                          decoration: const InputDecoration(
                            labelText: "Moneda (ISO) ej: USD",
                            prefixIcon: Icon(Icons.attach_money_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: decimalSep,
                          decoration: const InputDecoration(
                            labelText: "Separador decimal",
                            prefixIcon: Icon(Icons.more_horiz_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(value: ".", child: Text("Punto (.)")),
                            DropdownMenuItem(value: ",", child: Text("Coma (,)")),
                          ],
                          onChanged: (v) => setState(() => decimalSep = v ?? "."),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: thousandSep,
                          decoration: const InputDecoration(
                            labelText: "Separador miles",
                            prefixIcon: Icon(Icons.drag_handle_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(value: ",", child: Text("Coma (,)")),
                            DropdownMenuItem(value: ".", child: Text("Punto (.)")),
                            DropdownMenuItem(value: " ", child: Text("Espacio")),
                          ],
                          onChanged: (v) => setState(() => thousandSep = v ?? ","),
                        ),
                      ),
                    ],
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
                    title: const Text("Habilitar impuestos"),
                    subtitle: const Text("Se aplicará en Ventas por productos (próximo)."),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: taxRateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Tasa (%) ej: 7.50",
                            prefixIcon: Icon(Icons.percent_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: taxMode,
                          decoration: const InputDecoration(
                            labelText: "Modo",
                            prefixIcon: Icon(Icons.rule_rounded),
                          ),
                          items: const [
                            DropdownMenuItem(value: "inclusive", child: Text("Incluido")),
                            DropdownMenuItem(value: "exclusive", child: Text("Excluido")),
                          ],
                          onChanged: (v) => setState(() => taxMode = v ?? "inclusive"),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    final tenant = (tenantCtrl!.text.trim().isEmpty)
                        ? state.tenantName
                        : tenantCtrl!.text.trim();
                    final branch = (branchCtrl!.text.trim().isEmpty)
                        ? state.branchName
                        : branchCtrl!.text.trim();
                    final loc = (localeCtrl!.text.trim().isEmpty)
                        ? state.locale
                        : localeCtrl!.text.trim();
                    final curr = (currencyCtrl!.text.trim().isEmpty)
                        ? state.currencyCode
                        : currencyCtrl!.text.trim().toUpperCase();

                    final tr = double.tryParse(
                          taxRateCtrl!.text.trim().replaceAll(',', '.'),
                        ) ??
                        state.taxRate;

                    state.setConfig(
                      tenantName: tenant,
                      branchName: branch,
                      locale: loc,
                      currencyCode: curr,
                      decimalSep: decimalSep,
                      thousandSep: thousandSep,
                      taxEnabled: taxEnabled,
                      taxRate: tr,
                      taxMode: taxMode,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Configuración guardada ✅")),
                    );
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text("Guardar"),
                ),
              ],
            )
          ],
        ),
      ),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: Colors.black54))),
      ],
    );
  }
}

