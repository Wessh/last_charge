import 'dart:async';
import 'package:flutter/services.dart';
import '../models/charge_session.dart';
import '../repositories/battery_repository.dart';
import 'battery_service.dart';

class BackgroundService {
  static const MethodChannel _channel = MethodChannel(
    'com.wesleybr.last_charge/battery_service',
  );
  static const EventChannel _statusChannel = EventChannel(
    'com.wesleybr.last_charge/battery_status',
  );
  static const EventChannel _levelChannel = EventChannel(
    'com.wesleybr.last_charge/battery_level',
  );

  final BatteryService _batteryService = BatteryService();
  final ChargeRepository _repository = ChargeRepository();

  StreamSubscription? _statusSubscription;
  StreamSubscription? _levelSubscription;

  // Singleton
  static final BackgroundService _instance = BackgroundService._internal();

  factory BackgroundService() {
    return _instance;
  }

  BackgroundService._internal() {
    _setupEventChannels();
  }

  void _setupEventChannels() {
    // Monitorar mudanças no estado de carregamento
    _statusSubscription = _statusChannel
        .receiveBroadcastStream()
        .cast<Map<dynamic, dynamic>>()
        .listen((event) async {
          final bool isCharging = event['isCharging'];
          final int batteryLevel = event['batteryLevel'];

          await _handleBatteryChanged(isCharging, batteryLevel);
        });

    // Monitorar mudanças no nível da bateria
    _levelSubscription = _levelChannel.receiveBroadcastStream().cast<int>().listen((
      batteryLevel,
    ) {
      // Atualizar o nível da bateria no serviço
      // Isso é apenas para atualizações de nível sem mudança no estado de carregamento
    });
  }

  Future<void> _handleBatteryChanged(bool isCharging, int batteryLevel) async {
    final wasCharging = await _batteryService.isCharging();

    // Atualiza o estado da bateria no serviço
    _batteryService.setIsCharging(isCharging);

    // Detecta mudança no estado de carregamento
    if (!wasCharging && isCharging) {
      // Começou a carregar
      final session = await _repository.startChargeSession(batteryLevel);
      _batteryService.setCurrentChargeSessionId(session.id);
    } else if (wasCharging && !isCharging) {
      // Parou de carregar
      final sessionId = _batteryService.getCurrentChargeSessionId();
      if (sessionId != null) {
        await _repository.endChargeSession(sessionId, batteryLevel);
        _batteryService.setCurrentChargeSessionId(null);
      }
    }
  }

  // Inicia o serviço em segundo plano
  Future<bool> startService() async {
    try {
      return await _channel.invokeMethod('startBatteryMonitorService');
    } catch (e) {
      return false;
    }
  }

  // Para o serviço em segundo plano
  Future<bool> stopService() async {
    try {
      return await _channel.invokeMethod('stopBatteryMonitorService');
    } catch (e) {
      return false;
    }
  }

  // Solicita permissão para ignorar otimizações de bateria
  Future<bool> requestBatteryOptimizationPermission() async {
    try {
      return await _channel.invokeMethod(
        'requestBatteryOptimizationPermission',
      );
    } catch (e) {
      return false;
    }
  }

  // Verifica se o app está ignorando otimizações de bateria
  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _channel.invokeMethod('isIgnoringBatteryOptimizations');
    } catch (e) {
      return false;
    }
  }

  // Libera recursos
  void dispose() {
    _statusSubscription?.cancel();
    _levelSubscription?.cancel();
  }
}
