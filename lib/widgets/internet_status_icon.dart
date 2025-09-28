import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:io';

class InternetStatusIcon extends StatefulWidget {
  const InternetStatusIcon({super.key});

  @override
  State<InternetStatusIcon> createState() => _InternetStatusIconState();
}

class _InternetStatusIconState extends State<InternetStatusIcon> {
  bool? _online;
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _checkInternet();
    _subscription = Connectivity().onConnectivityChanged.listen((_) {
      _checkInternet();
    });
  }

  Future<void> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      setState(
          () => _online = result.isNotEmpty && result[0].rawAddress.isNotEmpty);
    } catch (_) {
      setState(() => _online = false);
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String tooltip;
    if (_online == null) {
      icon = Icons.help_outline;
      color = Colors.grey;
      tooltip = 'Sjekker internett...';
    } else if (_online == false) {
      icon = Icons.cloud_off;
      color = Colors.red;
      tooltip = 'Ingen internettforbindelse';
    } else {
      icon = Icons.cloud_done;
      color = Colors.green;
      tooltip = 'Online';
    }
    return Icon(icon, color: color, semanticLabel: tooltip);
  }
}
