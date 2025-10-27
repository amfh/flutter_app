import 'package:flutter/material.dart';
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
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.library_books,
                  color: Colors.white,
                  size: 36,
                ),
                SizedBox(height: 6),
                Text(
                  'Kompetansebiblioteket',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'VVS Publikasjoner',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
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
}
