import 'dart:convert';

class IrrigationSystem {
  final String systemId;
  final String name;
  final String status;
  final int smart;
  final Hardware hardware;
  final List<Schedule> schedules;

  IrrigationSystem({
    required this.systemId,
    required this.name,
    required this.status,
    required this.smart,
    required this.hardware,
    required this.schedules,
  });

  factory IrrigationSystem.fromJson(Map<String, dynamic> json) {
    return IrrigationSystem(
      systemId: json['system_id'] ?? '',
      name: json['name'] ?? '',
      status: json['status'] ?? 'disabled',
      smart: json['smart'] ?? 0,
      hardware: Hardware.fromJson(json['hardware'] ?? {}),
      schedules: (json['schedules'] as List? ?? [])
          .map((s) => Schedule.fromJson(s))
          .toList(),
    );
  }
}

class Hardware {
  final Motor motor;
  final List<Sensor> sensors;
  final List<Segment> segments;

  Hardware({
    required this.motor,
    required this.sensors,
    required this.segments,
  });

  factory Hardware.fromJson(Map<String, dynamic> json) {
    return Hardware(
      motor: Motor.fromJson(json['motor'] ?? {}),
      sensors: (json['sensors'] as List? ?? [])
          .map((s) => Sensor.fromJson(s))
          .toList(),
      segments: (json['segments'] as List? ?? [])
          .map((s) => Segment.fromJson(s))
          .toList(),
    );
  }
}

class Motor {
  final int id;
  final String name;
  final String type;
  final int startDelayMs;

  Motor({
    required this.id,
    required this.name,
    required this.type,
    required this.startDelayMs,
  });

  factory Motor.fromJson(Map<String, dynamic> json) {
    return Motor(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      startDelayMs: json['start_delay_ms'] ?? 0,
    );
  }
}

class Sensor {
  final String type;
  final int id;
  final String name;

  Sensor({
    required this.type,
    required this.id,
    required this.name,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    return Sensor(
      type: json['type'] ?? '',
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
    );
  }
}

class Segment {
  final int id;
  final int relayId;
  final String name;
  final double x;
  final double y;
  final bool isPlaced;

  Segment({
    required this.id,
    required this.relayId,
    required this.name,
    required this.x,
    required this.y,
    required this.isPlaced,
  });

  factory Segment.fromJson(Map<String, dynamic> json) {
    return Segment(
      id: json['id'] ?? 0,
      relayId: json['relay_id'] ?? 0,
      name: json['name'] ?? '',
      x: (json['x'] ?? 0).toDouble(),
      y: (json['y'] ?? 0).toDouble(),
      isPlaced: json['isPlaced'] ?? false,
    );
  }
}

class Schedule {
  final String id;
  final String startTime;
  final List<String> activeDays;
  final int overlapSeconds;
  final List<DurationItem> durations;

  Schedule({
    required this.id,
    required this.startTime,
    required this.activeDays,
    required this.overlapSeconds,
    required this.durations,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      id: json['id']?.toString() ?? '',
      startTime: json['start_time'] ?? '',
      activeDays: List<String>.from(json['active_days'] ?? []),
      overlapSeconds: json['overlap_seconds'] ?? 0,
      durations: (json['durations'] as List? ?? [])
          .map((d) => DurationItem.fromJson(d))
          .toList(),
    );
  }
}

class DurationItem {
  final int id;
  final int segmentId;
  final int relayId;
  final int time;

  DurationItem({
    required this.id,
    required this.segmentId,
    required this.relayId,
    required this.time,
  });

  factory DurationItem.fromJson(Map<String, dynamic> json) {
    return DurationItem(
      id: json['id'] ?? 0,
      segmentId: json['segment_id'] ?? 0,
      relayId: json['relay_id'] ?? 0,
      time: json['time'] ?? 0,
    );
  }
}
