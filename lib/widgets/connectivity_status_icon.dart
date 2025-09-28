import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityStatusIcon extends StatefulWidget {
  const ConnectivityStatusIcon({super.key});

  @override
  State<ConnectivityStatusIcon> createState() => _ConnectivityStatusIconState();
}

class _ConnectivityStatusIconState extends State<ConnectivityStatusIcon> {
  ConnectivityResult? _status;
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    _init();
    _connectivity.onConnectivityChanged.listen((result) {
      setState(
        () => _status = result is ConnectivityResult
            ? result as ConnectivityResult
            : ConnectivityResult.none,
      );
    });
  }

  Future<void> _init() async {
    final result = await _connectivity.checkConnectivity();
    setState(
      () => _status = result is ConnectivityResult
          ? result as ConnectivityResult
          : ConnectivityResult.none,
    );
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    String tooltip;
    if (_status == null) {
      icon = Icons.help_outline;
      color = Colors.grey;
      tooltip = 'Sjekker tilkobling...';
    } else if (_status == ConnectivityResult.none) {
      icon = Icons.cloud_off;
      color = Colors.red;
      tooltip = 'Offline';
    } else {
      icon = Icons.cloud_done;
      color = Colors.green;
      tooltip = 'Online';
    }
    return Icon(icon, color: color, semanticLabel: tooltip);
  }
}
