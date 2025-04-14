import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/models/charge_session.dart';
import '../../data/repositories/battery_repository.dart';
import '../../data/services/battery_service.dart';
import '../../data/services/background_service.dart';

class ChargeController extends ChangeNotifier {
  final ChargeRepository _repository = ChargeRepository();
  final BatteryService _service = BatteryService();
  final BackgroundService _backgroundService = BackgroundService();

  List<ChargeSession> _sessions = [];
  int _currentBatteryLevel = 0;
  bool _isCharging = false;
  bool _isLoading = false;
  bool _isOptimizationDisabled = false;
  StreamSubscription? _batteryStateSubscription;

  List<ChargeSession> get sessions => _sessions;
  int get currentBatteryLevel => _currentBatteryLevel;
  bool get isCharging => _isCharging;
  bool get isLoading => _isLoading;
  bool get isInChargeSession => _service.isInChargeSession();
  bool get isOptimizationDisabled => _isOptimizationDisabled;

  ChargeController() {
    _init();
  }

  Future<void> _init() async {
    await loadChargeSessions();
    await updateBatteryStatus();
    startMonitoringBattery();

    // Iniciar serviço em segundo plano
    await _backgroundService.startService();

    // Verificar status de otimização de bateria
    _isOptimizationDisabled =
        await _backgroundService.isIgnoringBatteryOptimizations();
    notifyListeners();
  }

  Future<void> loadChargeSessions() async {
    _isLoading = true;
    notifyListeners();

    try {
      _sessions = await _repository.getChargeSessions();
      _currentBatteryLevel = await _service.getBatteryLevel();
      _isCharging = await _service.isCharging();
    } catch (e) {
      debugPrint('Error loading charge sessions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateBatteryStatus() async {
    try {
      _currentBatteryLevel = await _service.getBatteryLevel();
      final wasCharging = _isCharging;
      _isCharging = await _service.isCharging();

      // Detecta mudança no estado de carregamento
      if (!wasCharging && _isCharging) {
        // Começou a carregar
        await startChargeSession();
      } else if (wasCharging && !_isCharging) {
        // Parou de carregar
        await endChargeSession();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating battery status: $e');
    }
  }

  Future<void> startChargeSession() async {
    try {
      // Inicia uma nova sessão apenas se não estiver em uma sessão ativa
      if (!_service.isInChargeSession()) {
        final session = await _repository.startChargeSession(
          _currentBatteryLevel,
        );
        _service.setCurrentChargeSessionId(session.id);
        _service.setIsCharging(true);
        await loadChargeSessions(); // Recarrega a lista
      }
    } catch (e) {
      debugPrint('Error starting charge session: $e');
    }
  }

  Future<void> endChargeSession() async {
    try {
      final sessionId = _service.getCurrentChargeSessionId();
      if (sessionId != null) {
        await _repository.endChargeSession(sessionId, _currentBatteryLevel);
        _service.setCurrentChargeSessionId(null);
        _service.setIsCharging(false);
        await loadChargeSessions(); // Recarrega a lista
      }
    } catch (e) {
      debugPrint('Error ending charge session: $e');
    }
  }

  void startMonitoringBattery() {
    // Cancela qualquer inscrição anterior
    _batteryStateSubscription?.cancel();

    // Monitora mudanças no estado da bateria
    _batteryStateSubscription = _service.onBatteryStateChanged().listen((
      state,
    ) {
      updateBatteryStatus();
    });
  }

  @override
  void dispose() {
    _batteryStateSubscription?.cancel();
    _backgroundService.dispose();
    super.dispose();
  }

  // Solicita permissão para ignorar otimizações de bateria
  Future<void> requestBatteryOptimization() async {
    await _backgroundService.requestBatteryOptimizationPermission();
    _isOptimizationDisabled =
        await _backgroundService.isIgnoringBatteryOptimizations();
    notifyListeners();
  }

  // Obtém a diferença de tempo formatada entre duas sessões
  String getDifferenceText(int index) {
    if (index >= _sessions.length - 1) return 'Primeira sessão';

    final currentSession = _sessions[index];
    final previousSession = _sessions[index + 1];

    return currentSession.getDifferenceFormatted(previousSession);
  }
}
