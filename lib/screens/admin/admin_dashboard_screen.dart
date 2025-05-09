import 'package:flutter/material.dart';
import 'package:sist_link1/screens/admin/admin_user_list_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  Widget _buildDashboardItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Card(
      elevation: 1.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
      child: ListTile(
        leading: Icon(
          icon,
          color: iconColor ?? Theme.of(context).primaryColor,
          size: 28,
        ),
        title: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 10.0,
          horizontal: 16.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          _buildDashboardItem(
            context: context,
            icon: Icons.people_alt_outlined,
            title: 'Manage Users',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AdminUserListScreen(),
                ),
              );
            },
          ),
          _buildDashboardItem(
            context: context,
            icon: Icons.report_problem_outlined,
            iconColor: Colors.orange[700],
            title: 'Moderate Content',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Content Moderation screen not implemented yet.',
                  ),
                ),
              );
            },
          ),
          _buildDashboardItem(
            context: context,
            icon: Icons.event_note_outlined,
            iconColor: Colors.green[700],
            title: 'Manage Events',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Manage Events screen not implemented yet.'),
                ),
              );
            },
          ),
          // Add more admin features here using _buildDashboardItem
        ],
      ),
    );
  }
}
