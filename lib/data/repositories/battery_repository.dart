import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/charge_session.dart';
import '../../core/constants/app_constants.dart';

class ChargeRepository {
  static const String _storageKey = AppConstants.chargeSessionsKey;

  // Obtém todas as sessões de carregamento
  Future<List<ChargeSession>> getChargeSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList(_storageKey) ?? [];

      return sessionsJson
          .map((json) => ChargeSession.fromJson(jsonDecode(json)))
          .toList()
          .reversed
          .toList(); // Mais recentes primeiro
    } catch (e) {
      // Em caso de erro, retorna uma lista vazia
      return [];
    }
  }

  // Salva uma nova sessão de carregamento
  Future<void> saveChargeSession(ChargeSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionsJson = prefs.getStringList(_storageKey) ?? [];

      sessionsJson.add(jsonEncode(session.toJson()));
      await prefs.setStringList(_storageKey, sessionsJson);
    } catch (e) {
      // Tratamento de erro
    }
  }

  // Inicia uma nova sessão de carregamento
  Future<ChargeSession> startChargeSession(int batteryLevel) async {
    final sessions = await getChargeSessions();
    final newId = sessions.isEmpty ? 1 : sessions.first.id + 1;

    final session = ChargeSession(
      id: newId,
      startTime: DateTime.now(),
      endTime: null,
      startBatteryLevel: batteryLevel,
      endBatteryLevel: batteryLevel,
      chargeDuration: Duration.zero,
    );

    await saveChargeSession(session);
    return session;
  }

  // Finaliza uma sessão de carregamento
  Future<ChargeSession> endChargeSession(
    int sessionId,
    int batteryLevel,
  ) async {
    final sessions = await getChargeSessions();
    final sessionIndex = sessions.indexWhere((s) => s.id == sessionId);

    if (sessionIndex == -1) {
      throw Exception('Sessão de carregamento não encontrada');
    }

    final session = sessions[sessionIndex];
    final endTime = DateTime.now();
    final duration = endTime.difference(session.startTime);

    final updatedSession = ChargeSession(
      id: session.id,
      startTime: session.startTime,
      endTime: endTime,
      startBatteryLevel: session.startBatteryLevel,
      endBatteryLevel: batteryLevel,
      chargeDuration: duration,
    );

    // Atualiza a sessão na lista
    final allSessions = await getChargeSessions();
    final updatedSessions = allSessions.toList();
    updatedSessions[sessionIndex] = updatedSession;

    // Salva a lista atualizada
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson =
        updatedSessions.map((s) => jsonEncode(s.toJson())).toList();

    await prefs.setStringList(_storageKey, sessionsJson);
    return updatedSession;
  }

  // Limpa todas as sessões de carregamento
  Future<void> clearChargeSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
