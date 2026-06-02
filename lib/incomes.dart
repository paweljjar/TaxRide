import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

enum IncomeSource { bolt, uber, freenow }

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
      source: IncomeSource.values.firstWhere(
        (e) => e.name == json['source'] as String,
      ),
      type: IncomeType.values.firstWhere(
        (e) => e.name == json['type'] as String,
      ),
      gross: json['gross'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'source': source.name,
      'type': type.name,
      'gross': gross,
    };
  }
}

class IncomesScreen extends StatefulWidget {
  const IncomesScreen({super.key});

  @override
  State<StatefulWidget> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends State<IncomesScreen> {
  List<Income> _incomes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadIncomes();
  }

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/incomesdata.json');
  }

  Future<void> _loadIncomes() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonData = json.decode(contents);

        setState(() {
          _incomes = jsonData
              .map((item) => Income.fromJson(item as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Loading error: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveIncomes(List<Income> newIncomes) async {
    try {
      final file = await _getLocalFile();

      final jsonData = newIncomes.map((i) => i.toJson()).toList();
      final String jsonString = json.encode(jsonData);

      await file.writeAsString(jsonString);

      setState(() {
        _incomes = newIncomes;
      });
    } catch (e) {
      debugPrint("Saving error: $e");
    }
  }

  Future<void> _editIncome(String oldId, Income updatedIncome) async {
    final index = _incomes.indexWhere((inv) => inv.id == oldId);
    if (index != -1) {
      final updatedList = List<Income>.from(_incomes);
      updatedList[index] = updatedIncome;
      await _saveIncomes(updatedList);
    }
  }

  Future<void> _deleteIncome(String id) async {
    final index = _incomes.indexWhere((inv) => inv.id == id);
    final deletedIncome = _incomes[index];
    final updatedIncomes = _incomes.where((inv) => inv.id != id).toList();
    await _saveIncomes(updatedIncomes);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Przychód został usunięty'),
        action: SnackBarAction(
          label: 'COFNIJ',
          onPressed: () {
            final restoredIncomes = List<Income>.from(_incomes);
            restoredIncomes.insert(index, deletedIncome);
            _saveIncomes(restoredIncomes);
          },
        ),
      ),
    );
  }

  Map<int, Map<int, List<Income>>> _getNestedGroupedIncomes() {
    final sortedIncomes = List<Income>.from(_incomes)
      ..sort((a, b) => a.date.compareTo(b.date));

    final Map<int, Map<int, List<Income>>> groups = {};

    for (var income in sortedIncomes) {
      final year = income.date.year;
      final month = income.date.month;

      if (!groups.containsKey(year)) {
        groups[year] = {};
      }

      if (!groups[year]!.containsKey(month)) {
        groups[year]![month] = [];
      }

      groups[year]![month]!.add(income);
    }
    return groups;
  }

  String _getMonthName(int month) {
    final dateTime = DateTime(2000, month);
    return DateFormat('MMMM', 'pl_PL').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final nestedGroups = _getNestedGroupedIncomes();
    final years = nestedGroups.keys.toList()..sort((a, b) => a.compareTo(b));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje Przychody'),
        centerTitle: true,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _incomes.isEmpty
              ? const Center(child: Text('Brak przychodów'))
              : ListView.builder(
                  itemCount: years.length,
                  itemBuilder: (context, yearIndex) {
                    final year = years[yearIndex];
                    final monthsMap = nestedGroups[year]!;
                    final months = monthsMap.keys.toList()..sort((a, b) => a.compareTo(b));

                    return ExpansionTile(
                      title: Text(
                        '$year',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      children: months.map((month) {
                        final incomes = monthsMap[month]!;
                        return ExpansionTile(
                          title: Text(
                            _getMonthName(month).toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          children: incomes.map((income) {
                            return Dismissible(
                              key: Key(income.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) => _deleteIncome(income.id),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => IncomeDetailScreen(
                                        income: income,
                                        onDelete: () => _deleteIncome(income.id),
                                        onEdit: (updated) => _editIncome(income.id, updated),
                                      ),
                                    ),
                                  );
                                },
                                leading: const Icon(Icons.description_outlined),
                                title: Text(
                                  income.source.name.toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.w500)
                                ),
                                subtitle: Text(
                                  'Data: ${DateFormat('dd.MM.yyyy').format(income.date)}',
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${income.gross} zł',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const Text('brutto', style: TextStyle(fontSize: 10)),
                                  ]
                                )
                              )
                            );
                          }).toList(),
                        );
                      }).toList(),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          //TODO: AddIncomeScreen
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white)
      )
    );
  }
}

class IncomeDetailScreen extends StatelessWidget {
  final Income income;
  final VoidCallback onDelete;
  final Function(Income) onEdit;

  const IncomeDetailScreen({
    super.key,
    required this.income,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final double grossVal = double.tryParse(income.gross.replaceAll(',', '.')) ?? 0;
    final String formattedDate = DateFormat('dd.MM.yyyy').format(income.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Szczegóły Przychodu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              //TODO: AddIncomeScreen
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Usuń przychód'),
                  content: const Text('Czy na pewno chcesz usunąć ten przychód?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ANULUJ'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        onDelete();
                      },
                      child: const Text('USUŃ', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    const Icon(Icons.receipt_long, size: 64, color: Colors.blueGrey),
                    const SizedBox(height: 16),
                    Text(
                      income.source.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 32),
                    _buildDetailRow('Data wystawienia', formattedDate),
                    _buildDetailRow('Kwota Brutto', '$grossVal zł', isBold: true),
                  ]
                )
              )
            )
          ]
        )
      )
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
