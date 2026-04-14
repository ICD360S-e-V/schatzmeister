import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// Sidebar menu item for admin dashboard
class SidebarMenuItem extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const SidebarMenuItem({
    super.key,
    required this.index,
    required this.selectedIndex,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? const Color(0xFF4a90d9) : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? const Color(0xFF4a90d9) : Colors.grey.shade400,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// User info header in sidebar
class SidebarUserInfo extends StatelessWidget {
  final String userName;
  final String mitgliedernummer;

  const SidebarUserInfo({
    super.key,
    required this.userName,
    required this.mitgliedernummer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0xFF4a90d9),
            child: Icon(Icons.person, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  mitgliedernummer,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Complete sidebar widget for admin dashboard
class DashboardSidebar extends StatelessWidget {
  final String userName;
  final String mitgliedernummer;
  final int selectedMenuIndex;
  final Function(int) onMenuSelected;

  const DashboardSidebar({
    super.key,
    required this.userName,
    required this.mitgliedernummer,
    required this.selectedMenuIndex,
    required this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      width: 250,
      color: const Color(0xFF1a1a2e),
      child: Column(
        children: [
          const SizedBox(height: 16),
          SidebarUserInfo(
            userName: userName,
            mitgliedernummer: mitgliedernummer,
          ),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 8),
          SidebarMenuItem(
            index: 0,
            selectedIndex: selectedMenuIndex,
            icon: Icons.dashboard,
            title: l.dashboard,
            onTap: () => onMenuSelected(0),
          ),
          SidebarMenuItem(
            index: 1,
            selectedIndex: selectedMenuIndex,
            icon: Icons.account_balance_wallet,
            title: l.financialManagement,
            onTap: () => onMenuSelected(1),
          ),
          SidebarMenuItem(
            index: 2,
            selectedIndex: selectedMenuIndex,
            icon: Icons.confirmation_number,
            title: l.myTickets,
            onTap: () => onMenuSelected(2),
          ),
          SidebarMenuItem(
            index: 3,
            selectedIndex: selectedMenuIndex,
            icon: Icons.calendar_month,
            title: l.myAppointments,
            onTap: () => onMenuSelected(3),
          ),
          SidebarMenuItem(
            index: 4,
            selectedIndex: selectedMenuIndex,
            icon: Icons.business,
            title: l.organizationManagement,
            onTap: () => onMenuSelected(4),
          ),
        ],
      ),
    );
  }
}
