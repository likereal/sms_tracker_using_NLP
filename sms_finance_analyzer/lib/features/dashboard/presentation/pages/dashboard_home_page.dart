import 'package:flutter/material.dart';
import './expenses_page.dart';

class DashboardHomePage extends StatelessWidget {
  const DashboardHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2193b0), Color(0xFF6dd5ed)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Welcome!',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _HomeButton(
                    icon: Icons.pie_chart,
                    label: 'Expenses',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ExpensesPage()),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _HomeButton(
                    icon: Icons.show_chart,
                    label: 'Stocks',
                    onTap: () {
                      // TODO: Implement Stocks page
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stocks page coming soon!')),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _HomeButton(
                    icon: Icons.people,
                    label: 'Community',
                    onTap: () {
                      // TODO: Implement Community page
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Community page coming soon!')),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _HomeButton(
                    icon: Icons.person,
                    label: 'Profile',
                    onTap: () {
                      // TODO: Implement Profile page
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile page coming soon!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Text(
            label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF2193b0),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        onPressed: onTap,
      ),
    );
  }
} 