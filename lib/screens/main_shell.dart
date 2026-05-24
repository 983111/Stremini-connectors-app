import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../providers/auth_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'documents/documents_screen.dart';
import 'mail/mail_screen.dart';
import 'drive/drive_screen.dart';
import 'databases/databases_screen.dart';
import 'forms/forms_screen.dart';
import 'slides/slides_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  final List<_NavItem> _items = const [
    _NavItem(icon: Icons.grid_view_rounded, label: 'Dashboard'),
    _NavItem(icon: Icons.description_outlined, label: 'Docs'),
    _NavItem(icon: Icons.mail_outline_rounded, label: 'Mail'),
    _NavItem(icon: Icons.folder_outlined, label: 'Drive'),
    _NavItem(icon: Icons.table_chart_outlined, label: 'Data'),
    _NavItem(icon: Icons.list_alt_outlined, label: 'Forms'),
    _NavItem(icon: Icons.slideshow_outlined, label: 'Slides'),
  ];

  final List<Widget> _screens = const [
    DashboardScreen(),
    DocumentsScreen(),
    MailScreen(),
    DriveScreen(),
    DatabasesScreen(),
    FormsScreen(),
    SlidesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        items: _items,
        selectedIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

class _BottomNav extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSurface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isSelected = i == selectedIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        size: 20,
                        color: isSelected
                            ? AppColors.foreground
                            : AppColors.mutedLight,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? AppColors.foreground
                              : AppColors.mutedLight,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}