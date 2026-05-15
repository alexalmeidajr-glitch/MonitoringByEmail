import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models.dart';
import '../email_service.dart';
import 'tab_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _syncing = false;
  Timer? _periodicTimer;

  @override
  void initState() {
    super.initState();
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      final state = context.read<AppState>();
      BackgroundEmailPoller.poll(state.config).then((_) {
        state.updateLastSync(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  Future<void> _syncNow(AppState state) async {
    setState(() {
      _syncing = true;
    });
    await BackgroundEmailPoller.poll(state.config);
    state.updateLastSync(DateTime.now());
    setState(() {
      _syncing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('MonitoringByEmail'),
          actions: [
            IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.pushNamed(context, '/config')),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nenhuma aba criada ainda.', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              const Text('Configure a conta de email e aguarde a leitura dos emails.'),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.sync),
                label: Text(_syncing ? 'Sincronizando...' : 'Sincronizar agora'),
                onPressed: _syncing ? null : () => _syncNow(state),
              ),
              const SizedBox(height: 12),
              Text('Última sincronização: ${state.lastSync.toLocal()}'),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: state.tabs.length,
      initialIndex: state.selectedIndex.clamp(0, state.tabs.length - 1),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('MonitoringByEmail'),
          actions: [
            IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.pushNamed(context, '/config')),
            IconButton(icon: const Icon(Icons.sync), onPressed: _syncing ? null : () => _syncNow(state)),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: state.tabs.map((tab) => Tab(text: tab.name)).toList(),
            onTap: (index) {
              state.selectedIndex = index;
            },
          ),
        ),
        body: TabBarView(
          children: state.tabs.map((tab) => TabView(tab: tab)).toList(),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text('Última sincronização: ${state.lastSync.toLocal()}'),
        ),
      ),
    );
  }
}
