enum IncomeSource { bolt, uber, freenow}
enum IncomeType { basic, bonus }

class Income {
  final String id;
  final DateTime date;
  final IncomeSource source;
  final IncomeType type;
  final String gross;

  Income({
    required this.id,
    required this.date,
    required this.source,
    required this.type,
    required this.gross,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      source: IncomeSource.values.firstWhere((e) => e.name == json['source'] as String),
      type: IncomeType.values.firstWhere((e) => e.name == json['type'] as String),
      gross: json['gross'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'source': source.name,
      'type': type.name,
      'gross': gross
    };
  }
}