import 'package:flutter/material.dart';
import 'package:flutter_app/screens/about_screen.dart';
import '../screens/publication_list_screen.dart';
import '../screens/bookmarks_screen.dart';
import '../screens/my_page_screen.dart';
import '../main.dart';

import 'internet_status_icon.dart';

class MainScaffold extends StatefulWidget {
  final Widget body;
  final String title;
  final List<Widget>? actions;
  const MainScaffold({
    super.key,
    required this.body,
    required this.title,
    this.actions,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check login status when dependencies change (e.g., when navigating back)
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final isLoggedIn = await UserSession.instance.isLoggedIn();
    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
      });
    }
  }

  // Method to refresh login status when returning from login page
  void _refreshLoginStatus() {
    _checkLoginStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          const InternetStatusIcon(),
          if (widget.actions != null) ...widget.actions!,
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text(
                'Meny',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Publikasjoner'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PublicationListScreen(),
                  ),
                  (route) => false,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('Bokmerker'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: const Text('Min side'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MyPageScreen(
                      idToken: UserSession.instance.idToken,
                      userEmail: UserSession.instance.userEmail,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(_isLoggedIn ? Icons.check_circle : Icons.login),
              title: Text(_isLoggedIn ? 'Logget inn' : 'Logg inn'),
              onTap: _isLoggedIn
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const B2CLoginPageWrapper()),
                      );
                      // Refresh login status when returning from login page
                      _refreshLoginStatus();
                    },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Om appen'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: widget.body,
    );
  }
}
