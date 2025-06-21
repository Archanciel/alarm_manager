// lib/models/alarm_model.dart
import 'package:uuid/uuid.dart';

class AlarmModel {
  final String id;
  final String name;
  final DateTime nextAlarmDateTime;
  final DateTime? lastAlarmDateTime;
  final DateTime? realAlarmDateTime;
  final AlarmPeriodicity periodicity;
  final AlarmLimit limit;
  final String audioFile;
  final bool isActive;

  AlarmModel({
    String? id,
    required this.name,
    required this.nextAlarmDateTime,
    this.lastAlarmDateTime,
    this.realAlarmDateTime,
    required this.periodicity,
    required this.limit,
    required this.audioFile,
    this.isActive = true,
  }) : id = id ?? const Uuid().v4();

  AlarmModel copyWith({
    String? name,
    DateTime? nextAlarmDateTime,
    DateTime? lastAlarmDateTime,
    DateTime? realAlarmDateTime,
    AlarmPeriodicity? periodicity,
    AlarmLimit? limit,
    String? audioFile,
    bool? isActive,
  }) {
    return AlarmModel(
      id: id,
      name: name ?? this.name,
      nextAlarmDateTime: nextAlarmDateTime ?? this.nextAlarmDateTime,
      lastAlarmDateTime: lastAlarmDateTime ?? this.lastAlarmDateTime,
      realAlarmDateTime: realAlarmDateTime ?? this.realAlarmDateTime,
      periodicity: periodicity ?? this.periodicity,
      limit: limit ?? this.limit,
      audioFile: audioFile ?? this.audioFile,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nextAlarmDateTime': nextAlarmDateTime.toIso8601String(),
      'lastAlarmDateTime': lastAlarmDateTime?.toIso8601String(),
      'realAlarmDateTime': realAlarmDateTime?.toIso8601String(),
      'periodicity': periodicity.toJson(),
      'limit': limit.toJson(),
      'audioFile': audioFile,
      'isActive': isActive,
    };
  }

  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    return AlarmModel(
      id: json['id'],
      name: json['name'],
      nextAlarmDateTime: DateTime.parse(json['nextAlarmDateTime']),
      lastAlarmDateTime:
          json['lastAlarmDateTime'] != null
              ? DateTime.parse(json['lastAlarmDateTime'])
              : null,
      realAlarmDateTime:
          json['realAlarmDateTime'] != null
              ? DateTime.parse(json['realAlarmDateTime'])
              : null,
      periodicity: AlarmPeriodicity.fromJson(json['periodicity']),
      limit: AlarmLimit.fromJson(json['limit']),
      audioFile: json['audioFile'],
      isActive: json['isActive'] ?? true,
    );
  }
}

class AlarmPeriodicity {
  final int days;
  final int hours;
  final int minutes;

  AlarmPeriodicity({
    required this.days,
    required this.hours,
    required this.minutes,
  });

  Duration get duration {
    return Duration(days: days, hours: hours, minutes: minutes);
  }

  String get formattedString {
    return '${days.toString().padLeft(2, '0')}:${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {'days': days, 'hours': hours, 'minutes': minutes};
  }

  factory AlarmPeriodicity.fromJson(Map<String, dynamic> json) {
    return AlarmPeriodicity(
      days: json['days'],
      hours: json['hours'],
      minutes: json['minutes'],
    );
  }

  factory AlarmPeriodicity.fromString(String periodicity) {
    final parts = periodicity.split(':');
    if (parts.length != 3) {
      throw ArgumentError('Invalid periodicity format. Expected dd:hh:mm');
    }

    return AlarmPeriodicity(
      days: int.parse(parts[0]),
      hours: int.parse(parts[1]),
      minutes: int.parse(parts[2]),
    );
  }
}

class AlarmLimit {
  final int fromHours;
  final int fromMinutes;
  final int toHours;
  final int toMinutes;

  AlarmLimit({
    required this.fromHours,
    required this.fromMinutes,
    required this.toHours,
    required this.toMinutes,
  });

  Duration get fromDuration {
    return Duration(hours: fromHours, minutes: fromMinutes);
  }

  Duration get toDuration {
    return Duration(hours: toHours, minutes: toMinutes);
  }

  String get formattedString {
    return 'from ${fromHours.toString().padLeft(2, '0')}:${fromMinutes.toString().padLeft(2, '0')} to ${toHours.toString().padLeft(2, '0')}:${toMinutes.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() {
    return {
      'fromHours': fromHours,
      'fromMinutes': fromMinutes,
      'toHours': toHours,
      'toMinutes': toMinutes,
    };
  }

  factory AlarmLimit.fromJson(Map<String, dynamic> json) {
    return AlarmLimit(
      fromHours: json['fromHours'],
      fromMinutes: json['fromMinutes'],
      toHours: json['toHours'],
      toMinutes: json['toMinutes'],
    );
  }

  factory AlarmLimit.fromString(String limit) {
    final parts = limit.split(':');
    if (parts.length != 4) {
      throw ArgumentError('Invalid limit format. Expected hh:mm hh:mm');
    }

    return AlarmLimit(
      fromHours: int.parse(parts[0]),
      fromMinutes: int.parse(parts[1]),
      toHours: int.parse(parts[2]),
      toMinutes: int.parse(parts[3]),
    );
  }
}
