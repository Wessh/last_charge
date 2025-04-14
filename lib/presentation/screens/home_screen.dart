import 'package:flutter/material.dart';
import '../controllers/battery_controller.dart';
import '../widgets/charge_session_card.dart';
import '../../core/utils/helpers.dart';
import '../../core/constants/app_constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ChargeController _controller = ChargeController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _controller.loadChargeSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            children: [
              _buildBatteryStatus(),
              Expanded(child: _buildSessionsList()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBatteryStatus() {
    final isCharging = _controller.isCharging;
    final batteryLevel = _controller.currentBatteryLevel;
    final isOptimizationDisabled = _controller.isOptimizationDisabled;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isCharging ? Icons.battery_charging_full : Icons.battery_full,
                color: isCharging ? Colors.green : Colors.blue,
                size: 48,
              ),
              const SizedBox(width: 16),
              Text(
                '$batteryLevel%',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCharging ? AppConstants.charging : AppConstants.notCharging,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: isCharging ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          if (!isOptimizationDisabled)
            ElevatedButton.icon(
              onPressed: () => _controller.requestBatteryOptimization(),
              icon: const Icon(Icons.power_settings_new),
              label: Text(AppConstants.allowBackgroundExecution),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          if (isOptimizationDisabled)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(
                  AppConstants.monitoringInBackground,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.green),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.battery_alert, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              AppConstants.noChargeSessions,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.connectCharger,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _controller.sessions.length,
        itemBuilder: (context, index) {
          final session = _controller.sessions[index];
          final differenceText = _controller.getDifferenceText(index);

          return ChargeSessionCard(
            session: session,
            differenceText: differenceText,
            onTap: () {
              Helpers.showSnackBar(
                context,
                'Duração: ${session.formattedDuration}',
              );
            },
          );
        },
      ),
    );
  }
}
