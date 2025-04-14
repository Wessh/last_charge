class ChargeSession {
  final int id;
  final DateTime startTime;
  final DateTime? endTime;
  final int startBatteryLevel;
  final int endBatteryLevel;
  final Duration chargeDuration;

  ChargeSession({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.startBatteryLevel,
    required this.endBatteryLevel,
    required this.chargeDuration,
  });

  factory ChargeSession.fromJson(Map<String, dynamic> json) {
    return ChargeSession(
      id: json['id'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      startBatteryLevel: json['startBatteryLevel'],
      endBatteryLevel: json['endBatteryLevel'],
      chargeDuration: Duration(milliseconds: json['chargeDurationMs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'startBatteryLevel': startBatteryLevel,
      'endBatteryLevel': endBatteryLevel,
      'chargeDurationMs': chargeDuration.inMilliseconds,
    };
  }

  // Calcula a diferença de tempo em relação a outra sessão de carregamento
  Duration getDifference(ChargeSession other) {
    return chargeDuration - other.chargeDuration;
  }

  // Retorna uma string formatada da duração (ex: 1h 30m 15s)
  String get formattedDuration {
    final hours = chargeDuration.inHours;
    final minutes = chargeDuration.inMinutes.remainder(60);
    final seconds = chargeDuration.inSeconds.remainder(60);
    
    final parts = <String>[];
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (seconds > 0 || parts.isEmpty) parts.add('${seconds}s');
    
    return parts.join(' ');
  }

  // Retorna uma string formatada da diferença (ex: +10m 5s ou -15m 30s)
  String getDifferenceFormatted(ChargeSession other) {
    final diff = getDifference(other);
    final isPositive = diff.inMilliseconds > 0;
    
    final hours = diff.inHours.abs();
    final minutes = diff.inMinutes.remainder(60).abs();
    final seconds = diff.inSeconds.remainder(60).abs();
    
    final parts = <String>[];
    if (hours > 0) parts.add('${hours}h');
    if (minutes > 0) parts.add('${minutes}m');
    if (seconds > 0 || parts.isEmpty) parts.add('${seconds}s');
    
    return '${isPositive ? '+' : '-'} ${parts.join(' ')}';
  }
}
