import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrangeAccent),
      ),
      home: const App(),
    );
  }
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: TabBarView(
          children: [
            InvoicesScreen(),
            IncomeScreen(),
            TaxesScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          color: Theme.of(context).primaryColor,
          child: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.document_scanner_outlined), text: 'Faktury'),
              Tab(icon: Icon(Icons.money), text: 'Przychód'),
              Tab(icon: Icon(Icons.money_off), text: 'Podatki'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorPadding: EdgeInsets.all(5.0),
            indicatorColor: Colors.white,
          ),
        ),
      ),
    );
  }
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<dynamic> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoices.json');

      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          setState(() {
            _invoices = json.decode(contents) as List<dynamic>;
          });
        }
      }
    } catch (e) {
      print('Error loading invoices: $e');
    }
  }

  Map<String, Map<String, List<dynamic>>> _groupInvoicesByYearMonth(List<dynamic> invoices) {
    Map<String, Map<String, List<dynamic>>> grouped = {};
    for (var invoice in invoices) {
      if (invoice['date'] != null) {
        DateTime date = DateTime.parse(invoice['date']);
        String year = date.year.toString();
        String month = date.month.toString().padLeft(2, '0'); // Format month as MM

        if (!grouped.containsKey(year)) {
          grouped[year] = {};
        }
        if (!grouped[year]!.containsKey(month)) {
          grouped[year]![month] = [];
        }
        grouped[year]![month]!.add(invoice);
      }
    }
    // Sort years in descending order
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
  Widget build(BuildContext context) {
    final groupedInvoices = _groupInvoicesByYearMonth(_invoices);
    final years = groupedInvoices.keys.toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadInvoices,
        child: ListView.builder( // Outer list for years
          itemCount: years.length,
          itemBuilder: (context, yearIndex) {
            final year = years[yearIndex];
            final monthsData = groupedInvoices[year]!;
            final months = monthsData.keys.toList();
            return ExpansionTile(
              title: Text('Rok: $year'),
              children: months.map((month) { // Inner list for months within a year
                final monthInvoices = monthsData[month]!;
                return ExpansionTile(
                  title: Text('  Miesiąc: $month'),
                  children: monthInvoices.map((invoice) { // Innermost list for invoices within a month
                    return ListTile(
                      title: Text(invoice['title'] ?? 'Brak tytułu'),
                      subtitle: Text('Data: ${invoice['date']?.split(' ')[0] ?? 'Brak daty'} - Brutto: ${invoice['gross'] ?? 'Brak kwoty'}'),
                    );
                  }).toList(),
                );
              }).toList(),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          // Navigate to NewInvoiceScreen and wait for the result
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewInvoiceScreen()),
          );
          // If NewInvoiceScreen returned with a new invoice (e.g., true), reload invoices
          if (result == true) {
            await Future.delayed(const Duration(milliseconds: 250));
            _loadInvoices();
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class NewInvoiceScreen extends StatefulWidget {
  const NewInvoiceScreen({super.key});

  @override
  State<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends State<NewInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  final _titleController = TextEditingController();
  final _grossController = TextEditingController();
  final _vatController = TextEditingController();
  double _netValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text('Nowa Faktura'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              ListTile(
                title: Text(_selectedDate == null
                    ? 'Wybierz datę'
                    : 'Data: ${_selectedDate!.day.toString().padLeft(2, "0")}.${_selectedDate!.month.toString().padLeft(2, "0")}.${_selectedDate!.year}'.split(' ')[1]),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tytuł'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Proszę podać tytuł';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _grossController,
                decoration: const InputDecoration(labelText: 'Brutto'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateNet(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Proszę podać kwotę brutto';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Proszę podać poprawną liczbę';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _vatController,
                decoration: const InputDecoration(labelText: 'VAT (%)'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateNet(),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Proszę podać stawkę VAT';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Proszę podać poprawną liczbę';
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'Netto: ${_netValue.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate() &&
                      _selectedDate != null) {
                    // Stwórz mapę z danymi formularza
                    Map<String, dynamic> formData = {
                      'date': _selectedDate.toString(),
                      'title': _titleController.text,
                      'gross': _grossController.text,
                      'vat': _vatController.text,
                      'net': _netValue.toStringAsFixed(2),
                    };

                    // Zapisz dane do pliku JSON
                    _saveDataToJson(formData);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Dane zapisane'),
                      ),
                    );

                    Navigator.pop(context, true); // Return true to indicate a new invoice was added
                  } else if (_selectedDate == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Proszę wybrać datę')),
                    );
                  }
                },
                child: const Text('Wyślij'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  void _calculateNet() {
    final double gross = double.tryParse(_grossController.text) ?? 0.0;
    final double vatRate = (double.tryParse(_vatController.text) ?? 0.0) / 100;
    setState(() {
      _netValue = gross / (1 + vatRate);
    });
  }

  Future<void> _saveDataToJson(Map<String, dynamic> data) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoices.json');
      List<dynamic> jsonList = [];

      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          jsonList = json.decode(contents) as List<dynamic>;
        }
      }
      jsonList.add(data);
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('Error saving data to JSON: $e');
    }
  }
}

class IncomeScreen extends StatelessWidget {
  const IncomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Placeholder.',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}

class TaxesScreen extends StatelessWidget {
  const TaxesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Placeholder.',
        style: TextStyle(fontSize: 24),
      ),
    );
  }
}