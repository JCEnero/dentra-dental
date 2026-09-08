class ScreeningModel {
  final int id;
  final String date;       // short e.g. "Sep 7"
  final String fullDate;   // e.g. "September 7, 2026"
  final int images;
  final int teeth;
  final String region;
  final String weekday;

  const ScreeningModel({
    required this.id,
    required this.date,
    required this.fullDate,
    required this.images,
    required this.teeth,
    required this.region,
    required this.weekday,
  });
}
