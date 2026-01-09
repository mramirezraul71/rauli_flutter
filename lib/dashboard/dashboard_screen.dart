import 'package:flutter/material.dart';

import '../app/screens/inventory_screen.dart';
import '../app/screens/sales_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RAULI'),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TEMP: settings_screen.dart está roto; no lo importamos para que compile.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings deshabilitado temporalmente (se repara en el próximo paso).')),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text('FASE 1: Base estable en Windows (navegación activa: Ventas/Inventario).'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DashCard(
                  title: 'Producción',
                  icon: Icons.factory,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Producción: se conecta luego.')),
                    );
                  },
                ),
                _DashCard(
                  title: 'Ventas',
                  icon: Icons.point_of_sale,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SalesScreen()),
                    );
                  },
                ),
                _DashCard(
                  title: 'Inventario',
                  icon: Icons.inventory_2,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => InventoryScreen()),
                    );
                  },
                ),
                _DashCard(
                  title: 'Finanzas',
                  icon: Icons.account_balance_wallet,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Finanzas: se conecta luego.')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _DashCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(radius: 20, child: Icon(icon)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
