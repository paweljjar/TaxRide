import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

//#region incomes

class IncomesScreen extends StatefulWidget {
  const IncomesScreen({super.key});

  @override
  State<IncomesScreen> createState() => _IncomesScreenState();
}

class _IncomesScreenState extends State<IncomesScreen> {
  List<dynamic> _incomes = [];

  Future<void> _loadIncomes() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/incomesdata.json');

      if(await file.exists()){
        final contents = await file.readAsString();
        if (contents.isNotEmpty){
          setState(() {
            _incomes = json.decode(contents) as List<dynamic>;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading invoices: $e');
      }
    }
  }

  Map<String, Map<String, List<dynamic>>> _groupIncomesByYearMonth(List<dynamic> incomes) {
    Map<String, Map<String, List<dynamic>>> grouped = {};
    for (var income in incomes) {
      if (income['date'] != null) {
        DateTime date = DateTime.parse(income['date']);
        String year = date.year.toString();
        String month = date.month.toString().padLeft(2, '0'); // Format month as MM

        if (!grouped.containsKey(year)) {
          grouped[year] = {};
        }
        if (!grouped[year]!.containsKey(month)) {
          grouped[year]![month] = [];
        }
        grouped[year]![month]!.add(income);
      }
    }
    var sortedYears = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    Map<String, Map<String, List<dynamic>>> sortedGroupedData = {};
    for (var year in sortedYears) {
      // Sort months in descending order
      var sortedMonths = grouped[year]!.keys.toList()..sort((a, b) => b.compareTo(a));
      Map<String, List<dynamic>> sortedMonthData = {};
      for (var month in sortedMonths) {
        sortedMonthData[month] = grouped[year]![month]!;
      }
      sortedGroupedData[year] = sortedMonthData;
    }
    return sortedGroupedData;
  }

  @override
  void initState() {
    super.initState();
    _loadIncomes();
  }

  @override
  Widget build(BuildContext context) {
    final groupedIncomes = _groupIncomesByYearMonth(_incomes);
    final years = groupedIncomes.keys.toList();

    return Scaffold(
        body: RefreshIndicator(
            onRefresh: _loadIncomes,
            child: ListView.builder(
                itemCount: years.length,
                itemBuilder: (context, yearIndex) {
                  final year = years[yearIndex];
                  final monthsData = groupedIncomes[year]!;
                  final months = monthsData.keys.toList();
                  return ExpansionTile(
                    title: Text('Rok: $year'),
                    children: months.map((month) {
                      final monthIncomes = monthsData[month]!;
                      return ExpansionTile(
                        title: Text('  Miesiąc: $month'),
                        children: monthIncomes.map((income) {
                          String formattedDate = 'Brak daty';
                          if (income['date'] != null) {
                            try {
                              DateTime date = DateTime.parse(income['date'].split(' ')[0]);
                              formattedDate = "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
                            } catch (e) {
                              if(kDebugMode) {
                                print("Error parsing date: $e");
                              }
                            }
                          }
                          return Card(
                            margin: EdgeInsets.all(8.0),
                            child: ListTile(
                              title: Text(income['source'] ?? 'Inne źródło'),
                              subtitle: Text('Data: $formattedDate - ${income['type']} brutto: ${income['gross'] + ' zł' ?? 'Brak kwoty'}'),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => IncomeDetailScreen(income: income))
                                ).then((value) => {
                                  if(value == true && mounted){
                                    Future.delayed(const Duration(milliseconds: 100)),
                                    _loadIncomes()
                                  }
                                });
                              },
                            )
                          );
                        }).toList(),
                      );
                    }).toList(),
                  );
                }
            )
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NewIncomeScreen())
            );

            if(result == true){
              await Future.delayed(const Duration(milliseconds: 250));
              _loadIncomes();
            }
          },
          backgroundColor: Theme.of(context).primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        )
    );
  }
}

//#endregion

//#region newincome

class NewIncomeScreen extends StatefulWidget {
  const NewIncomeScreen({super.key});

  @override
  State<NewIncomeScreen> createState() => _NewIncomeScreenState();
}

class _NewIncomeScreenState extends State<NewIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  String? _source;
  final _grossController = TextEditingController();
  final _bonusController = TextEditingController();

  final List<Map<String, dynamic>> _sources = [
    {
      'name': "Uber",
      'logo': 'assets/uber_logo.png' // Przykładowa ścieżka do logo
    },
    {
      'name': "Bolt",
      'logo': 'assets/bolt_logo.png' // Przykładowa ścieżka do logo
    },
    {
      'name': "FreeNow",
      'logo': 'assets/freenow_logo.png' // Przykładowa ścieżka do logo
    }
  ];

  Future<void> _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2009, 6),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _saveDataToJson(Map<String, dynamic> data, Map<String, dynamic>? data2) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/incomesdata.json');

      List<dynamic> jsonList = [];

      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          jsonList = json.decode(contents) as List<dynamic>;
        }
      }

      jsonList.add(data);
      if(data2 != null){
        jsonList.add(data2);
      }
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      if (kDebugMode) {
        print('Error saving data to JSON: $e');
      }
    }
  }

  void _onAddButtonPressed() {
    if (_formKey.currentState!.validate() &&
        _selectedDate != null) {
      Map<String, dynamic> formDataIncome = {
        'id': DateTime
            .now()
            .millisecondsSinceEpoch
            .toString(),
        'date': _selectedDate.toString(),
        'source': _source,
        'type': "Przychód",
        'gross': _grossController.text,
      };

      Map<String, dynamic> formDataBonus = {
        'id': (DateTime
            .now()
            .millisecondsSinceEpoch + 100)
            .toString(),
        'date': _selectedDate.toString(),
        'source': _source,
        'type': "Bonus",
        'gross': _bonusController.text,
      };

      _saveDataToJson(formDataIncome, formDataBonus);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Dodano'),
          action: SnackBarAction(label: 'OK', onPressed: () => {}),),
      );

      Navigator.pop(context, true);
    } else if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Proszę wybrać datę'),
          action: SnackBarAction(label: 'OK', onPressed: () => {}),),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.arrow_back_ios)
          ),
        ),
        body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
                key: _formKey,
                child: ListView(
                    children: [
                      // Make sure to wrap showDatePicker with a Localizations widget
                      // or ensure MaterialApp provides MaterialLocalizations.
                      ListTile(
                        title: Text(_selectedDate == null
                            ? 'Wybierz datę'
                            : 'Data: ${_selectedDate!.day.toString().padLeft(
                            2, "0")}.${_selectedDate!.month.toString().padLeft(
                            2, "0")}.${_selectedDate!.year}'.split(' ')[1]),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickDate,
                      ),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Źródło'),
                        value: _source,
                        items: _sources.map((Map<String, dynamic> sourceData) {
                          String appName = sourceData['name'];
                          String appLogoPath = sourceData['logo'];
                          return DropdownMenuItem<String>(
                            value: appName,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(appName),
                                const SizedBox(width: 24),
                                Image.asset(appLogoPath, width: 24, height: 24)
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _source = newValue;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Proszę wybrać źródło przychodu';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _grossController,
                        decoration: const InputDecoration(
                            labelText: 'Przychód (brutto)'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Proszę podać kwotę';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Proszę podać poprawną liczbę';
                          }
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: _bonusController,
                        decoration: const InputDecoration(
                            labelText: 'Bonus'),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Proszę podać kwotę';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Proszę podać poprawną liczbę';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      ElevatedButton(
                          onPressed: _onAddButtonPressed,
                          child: const Text('Dodaj')
                      )
                    ]
                )
            )
        )
    );
  }
}

//#endregion

//#region incomedetail

class IncomeDetailScreen extends StatefulWidget {
  final Map<String, dynamic> income;

  const IncomeDetailScreen({super.key, required this.income});

  @override
  State<IncomeDetailScreen> createState() => _IncomeDetailScreenState();
}

class _IncomeDetailScreenState extends State<IncomeDetailScreen> {
  Future<void> _deleteIncome() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/incomesdata.json');
      List<dynamic> incomes = [];

      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          incomes = json.decode(contents) as List<dynamic>;
        }
      }

      incomes.removeWhere((inv) =>
      inv['id'] == widget.income['id']);

      await file.writeAsString(json.encode(incomes));

      Navigator.pop(context, true);
    } catch (e) {
      if(kDebugMode){
        print('Error deleting invoice: $e');
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(value, style: const TextStyle(fontSize: 16)))
          ],
        )
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Brak danych';
    try {
      DateTime date = DateTime.parse(dateString.split(' ')[0]);
      return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
    } catch (e) {
      return 'Błędny format daty';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () {
              Navigator.pop(context, false);
            },
          ),
          title: Text(widget.income['source'] ?? 'Szczegóły Przychodu')
      ),
      body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
              children: [
                _buildDetailRow('Data:', _formatDate(widget.income['date'])),
                _buildDetailRow('Typ:', widget.income['type']),
                _buildDetailRow('Kwota (brutto):', widget.income['gross'] + " zł"),
                const SizedBox(height: 20),
                ElevatedButton(
                    onPressed: () {
                      // Navigate to the edit invoice screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => EditIncomeScreen(income: widget.income)),
                      ).then((value) {
                        if(value == true && mounted){
                          // Reload data in InvoicesScreen
                          Navigator.pop(context, true);
                        }
                      });
                    },
                    child: const Text('Edytuj')
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                    onPressed: () {
                      showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: const Text("Potwierdź usunięcie"),
                              content: const Text('Czy na pewno chcesz usunąć ten wpis?'),
                              actions: <Widget>[
                                TextButton(
                                  child: const Text('Anuluj'),
                                  onPressed: () => Navigator.of(context).pop(), // Close the dialog
                                ),
                                TextButton(
                                  child: const Text('Usuń'),
                                  onPressed: () => {
                                    _deleteIncome(),
                                    Navigator.pop(context, true), // Indicate success and trigger reload
                                  }, // Proceed with deletion
                                ),
                              ],
                            );
                          }
                      );
                    },
                    child: const Text('Usuń')
                )
              ]
          )
      ),
    );
  }
}

//#endregion

//#region editIncome

class EditIncomeScreen extends StatefulWidget {
  final Map<String, dynamic> income;

  const EditIncomeScreen({super.key, required this.income});

  @override
  State<EditIncomeScreen> createState() => _EditIncomeScreenState();
}

class _EditIncomeScreenState extends State<EditIncomeScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime? _selectedDate;
  late TextEditingController _grossController;
  String? _selectedSource;

  final List<Map<String, dynamic>> _sources = [
    {
      'name': "Uber",
      'logo': 'assets/uber_logo.png'
    },
    {
      'name': "Bolt",
      'logo': 'assets/bolt_logo.png'
    },
    {
      'name': "FreeNow",
      'logo': 'assets/freenow_logo.png'
    }
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.parse(widget.income['date']);
    _grossController = TextEditingController(text: widget.income['gross']);
    _selectedSource = widget.income['source'];
  }

  Future<void> _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _updateIncome() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/incomesdata.json');
      List<dynamic> incomes = [];

      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          incomes = json.decode(contents) as List<dynamic>;
        }
      }

      int index = incomes.indexWhere((inc) => inc['id'] == widget.income['id']);
      if (index != -1) {
        incomes[index] = {
          'id': widget.income['id'],
          'date': _selectedDate!.toIso8601String(),
          'source': _selectedSource,
          'type': widget.income['type'], // Assuming type does not change or is handled elsewhere
          'gross': _grossController.text.trim(),
        };
        await file.writeAsString(json.encode(incomes));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Zaktualizowano wpis'), action: SnackBarAction(label: 'OK', onPressed: () {})),
        );
        Navigator.pop(context, true); // Indicate success
      }
    } else if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Proszę wybrać datę'), action: SnackBarAction(label: 'OK', onPressed: () {})),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edytuj Wpis'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context, false),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              ListTile(
                title: Text(_selectedDate == null ? 'Wybierz datę' : 'Data: ${_selectedDate!.day.toString().padLeft(2, "0")}.${_selectedDate!.month.toString().padLeft(2, "0")}.${_selectedDate!.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Źródło'),
                value: _selectedSource,
                items: _sources.map((Map<String, dynamic> sourceData) {
                  String appName = sourceData['name'];
                  String appLogoPath = sourceData['logo'];
                  return DropdownMenuItem<String>(
                    value: appName,
                    child: Row(
                      children: [
                        Image.asset(appLogoPath, width: 24, height: 24),
                        const SizedBox(width: 10),
                        Text(appName),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedSource = newValue;
                  });
                },
                validator: (value) => value == null || value.isEmpty ? 'Proszę wybrać źródło' : null,
              ),
              TextFormField(
                controller: _grossController,
                decoration: InputDecoration(labelText: 'Kwota (${widget.income['type']})'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Proszę podać kwotę';
                  if (double.tryParse(value) == null) return 'Proszę podać poprawną liczbę';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _updateIncome, child: const Text('Zapisz zmiany')),
            ],
          ),
        ),
      ),
    );
  }
}

//#endregion
