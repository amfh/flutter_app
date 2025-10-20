import 'package:flutter/material.dart';
import '../main.dart';
import '../services/new_user_data_service.dart';
import '../screens/new_publication_list_screen.dart';
import '../screens/new_my_page_screen.dart';
import '../screens/new_about_screen.dart';

class NewMainScaffold extends StatefulWidget {
  final Widget child;
  final String title;
  final String currentRoute;

  const NewMainScaffold({
    super.key,
    required this.child,
    required this.title,
    required this.currentRoute,
  });

  @override
  State<NewMainScaffold> createState() => _NewMainScaffoldState();
}

class _NewMainScaffoldState extends State<NewMainScaffold> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 2,
      ),
      drawer: _buildDrawer(context),
      body: widget.child,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width *
          0.5, // Make drawer 50% of screen width
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.library_books,
                  color: Colors.white,
                  size: 48,
                ),
                SizedBox(height: 8),
                Text(
                  'Kompetansebiblioteket',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'VVS Publikasjoner',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.library_books,
            title: 'Publikasjoner',
            route: '/publications',
            onTap: () => _navigateToPublications(context),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.person,
            title: 'Min side',
            route: '/my-page',
            onTap: () => _navigateToMyPage(context),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.info,
            title: 'Om appen',
            route: '/about',
            onTap: () => _navigateToAbout(context),
          ),
          const Divider(),
          _buildDrawerItem(
            context,
            icon: Icons.logout,
            title: 'Logg ut',
            route: '/logout',
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    required VoidCallback onTap,
  }) {
    final isSelected = widget.currentRoute == route;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Theme.of(context).primaryColor : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      selected: isSelected,
      onTap: () {
        Navigator.pop(context); // Close drawer
        onTap();
      },
    );
  }

  void _navigateToPublications(BuildContext context) {
    if (widget.currentRoute != '/publications') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const NewPublicationListScreen(),
        ),
      );
    }
  }

  void _navigateToMyPage(BuildContext context) {
    if (widget.currentRoute != '/my-page') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const NewMyPageScreen(),
        ),
      );
    }
  }

  void _navigateToAbout(BuildContext context) {
    if (widget.currentRoute != '/about') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const NewAboutScreen(),
        ),
      );
    }
  }

  void _logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logg ut'),
          content: const Text('Er du sikker på at du vil logge ut?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Avbryt'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _performLogout(context);
              },
              child: const Text('Logg ut'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout(BuildContext context) async {
    try {
      // Clear user session
      await UserSession.instance.clearSession();

      // Delete local user data (but keep downloaded publications for offline use)
      await UserDataService.instance.deleteUserData();

      // NOTE: We do NOT clear downloaded content to preserve offline publications
      // If you want to clear content on logout, uncomment the line below:
      // await NewPublicationService.instance.clearAllContent();

      if (context.mounted) {
        // Navigate back to login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const AuthWrapper(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      print('❌ Error during logout: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feil under utlogging. Prøv igjen.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
