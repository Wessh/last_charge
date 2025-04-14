import 'dart:async';
import 'package:battery_plus/battery_plus.dart';

class BatteryService {
  final Battery _battery = Battery();
  int? _currentChargeSessionId;
  bool _isCharging = false;

  // Obtém o nível atual da bateria
  Future<int> getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      return level;
    } catch (e) {
      return 0;
    }
  }

  // Verifica se o dispositivo está carregando
  Future<bool> isCharging() async {
    try {
      final state = await _battery.batteryState;
      return state == BatteryState.charging || state == BatteryState.full;
    } catch (e) {
      return false;
    }
  }

  // Stream para monitorar o estado da bateria
  Stream<BatteryState> onBatteryStateChanged() {
    return _battery.onBatteryStateChanged;
  }

  // Define o ID da sessão de carregamento atual
  void setCurrentChargeSessionId(int? sessionId) {
    _currentChargeSessionId = sessionId;
  }

  // Obtém o ID da sessão de carregamento atual
  int? getCurrentChargeSessionId() {
    return _currentChargeSessionId;
  }

  // Define se está carregando
  void setIsCharging(bool isCharging) {
    _isCharging = isCharging;
  }

  // Verifica se está em uma sessão de carregamento
  bool isInChargeSession() {
    return _isCharging && _currentChargeSessionId != null;
  }
}
