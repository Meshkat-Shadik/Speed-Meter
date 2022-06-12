import 'dart:convert';

LocationData locationDataFromMap(String str) =>
    LocationData.fromMap(json.decode(str));

String locationDataToMap(LocationData data) => json.encode(data.toMap());

class LocationData {
  LocationData({
    this.speed,
    this.totalDistance,
    this.distance,
  });

  double? speed;
  double? totalDistance;
  double? distance;

  LocationData copyWith({
    double? speed,
    double? totalDistance,
    double? distance,
  }) =>
      LocationData(
        speed: speed ?? this.speed,
        totalDistance: totalDistance ?? this.totalDistance,
        distance: distance ?? this.distance,
      );

  factory LocationData.fromMap(Map<String, dynamic> json) => LocationData(
        speed: json["speed"].toDouble(),
        totalDistance: json["total_distance"].toDouble(),
        distance: json["distance"].toDouble(),
      );

  Map<String, dynamic> toMap() => {
        "speed": speed,
        "total_distance": totalDistance,
        "distance": distance,
      };
}
