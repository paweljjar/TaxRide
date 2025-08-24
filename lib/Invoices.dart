import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

//#region invoices

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<dynamic> _invoices = [];

  Future<void> _loadInvoices() async {
    try{
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoicesdata.json');

      if(await file.exists()){
        final contents = await file.readAsString();
        if (contents.isNotEmpty){
          setState(() {
            _invoices = json.decode(contents) as List<dynamic>;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading invoices: $e');
      }
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
    var sortedYears = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    Map<String, Map<String, List<dynamic>>> sortedGroupedData = {};
    for (var year in sortedYears) {
      // Sort months in descending order
      var sortedMonths = grouped[year]!.keys.toList()..sort((a, b) => b.compareTo(a));
      Map<String, List<dynamic>> sortedMonthData = {};
      for (var month in sortedMonths) {
        // Sort invoices within each month by day in ascending order
        var invoicesInMonth = grouped[year]![month]!;
        invoicesInMonth.sort((a, b) => DateTime.parse(a['date']).day.compareTo(DateTime.parse(b['date']).day));
        sortedMonthData[month] = invoicesInMonth;
      }
      sortedGroupedData[year] = sortedMonthData;
    }
    return sortedGroupedData;
  }

  Map<String, double> _calculateMonthSummary(List<dynamic> monthInvoices) {
    double totalGross = 0;
    double totalVat = 0;

    for (var invoice in monthInvoices) {
      totalGross += double.tryParse(invoice['gross'].toString()) ?? 0.0;
      double net = double.tryParse(invoice['net'].toString()) ?? 0.0;
      totalVat += (double.tryParse(invoice['gross'].toString()) ?? 0.0) - net;
    }

    return {'totalGross': totalGross, 'totalVat': totalVat};
  }

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }
  @override
  Widget build(BuildContext context) {
    final groupedInvoices = _groupInvoicesByYearMonth(_invoices);
    final years = groupedInvoices.keys.toList();

    return Scaffold(
      body: RefreshIndicator(
          onRefresh: _loadInvoices,
          child: ListView.builder(
            itemCount: years.length,
            itemBuilder: (context, yearIndex) {
              final year = years[yearIndex];
              final monthsData = groupedInvoices[year]!;
              final months = monthsData.keys.toList();
              return ExpansionTile(
                title: Text('Rok: $year'),
                children: months.map((month) {
                  final monthInvoices = monthsData[month]!;
                  final monthSummary = _calculateMonthSummary(monthInvoices);
                  return ExpansionTile(
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(' Miesiąc: $month'),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(' Łącznie Brutto: ${monthSummary['totalGross']?.toStringAsFixed(2)} zł, Łączny VAT: ${monthSummary['totalVat']?.toStringAsFixed(2)} zł', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey)),
                        ),
                      ],
                    ),
                    children: [
                      ...monthInvoices.map((invoice) {
                        String formattedDate = 'Brak daty';
                        if (invoice['date'] != null) {
                          try {
                            DateTime date = DateTime.parse(invoice['date'].split(' ')[0]);
                            formattedDate = "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";
                          } catch (e) {
                            if(kDebugMode) {
                              print("Error parsing date: $e");
                            }
                          }
                        }
                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0), // Adjusted margin
                          child: ListTile(
                            title: Text(invoice['title'] ?? 'Brak tytułu'),
                            subtitle: Text('Data: $formattedDate - Brutto: ${invoice['gross'] + ' zł' ?? 'Brak kwoty'}'),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => InvoiceDetailScreen(invoice: invoice)),
                              ).then((value) => {
                                if(value == true && mounted){
                                  _loadInvoices()
                                }
                              });
                            },
                          )
                        );
                      }).toList(),
                    ]
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
            MaterialPageRoute(builder: (context) => const NewInvoiceScreen())
          );

          if(result == true){
            _loadInvoices();
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      )
    );
  }
}

//#endregion

//#region newinvoice

class NewInvoiceScreen extends StatefulWidget {
  const NewInvoiceScreen({super.key});

  @override
  State<NewInvoiceScreen> createState() => _NewInvoiceScreenState();
}

class _NewInvoiceScreenState extends State<NewInvoiceScreen>{
  final _formKey = GlobalKey<FormState>();
  DateTime? _selectedDate;
  final _titleController = TextEditingController();
  final _grossController = TextEditingController();
  String? _selectedVatRate;
  double _netValue = 0.0;
  double _vatValue = 0.0;

  final List<String> _vatRates = [
    '23%',
    '8%',
    '5%',
    '0%',
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

  Future<void> _saveDataToJson(Map<String, dynamic> data) async {
    try{
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoicesdata.json');

      List<dynamic> jsonList = [];

      if(await file.exists()) {
        final contents = await file.readAsString();
        if(contents.isNotEmpty) {
          jsonList = json.decode(contents) as List<dynamic>;
        }
      }
      
      jsonList.add(data);
      await file.writeAsString(json.encode(jsonList)).then((_) {
        // After saving, reload the invoices in the InvoicesScreen
        Navigator.pop(context, true); // Pass true to indicate success
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error saving data to JSON: $e');
      }
    }
  }

  void _calculate() {
    final double gross = double.tryParse(_grossController.text) ?? 0.0;
    final double vatRate = (double.tryParse(_selectedVatRate!.substring(0, _selectedVatRate!.length - 1)) ?? 0.0) / 100;
    setState(() {
      _netValue = gross / (1 + vatRate);
      _vatValue = gross - _netValue;
    });
  }

  void _onAddButtonPressed() {
    if (_formKey.currentState!.validate() &&
        _selectedDate != null) {
      Map<String, dynamic> formData = {
        'id': DateTime
            .now()
            .millisecondsSinceEpoch
            .toString(),
        'date': _selectedDate!.toIso8601String(),
        'title': _titleController.text.trim(),
        'gross': _grossController.text.trim(),
        'vat': double.tryParse(
            _selectedVatRate!.substring(0, _selectedVatRate!.length - 1)) ??
            0.0,
        'net': _netValue.toStringAsFixed(2).trim()
        // Include imagePath only if an image is selected
        // 'imagePath': _imageFile != null ? _imageFile!.path : null,

      };

      _saveDataToJson(formData).then((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Dodano'), action: SnackBarAction(label: 'OK', onPressed: () => {}),),
        );
      });    } else if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Proszę wybrać datę'), action: SnackBarAction(label: 'OK', onPressed: () => {}),),
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
              ListTile(
                title: Text(_selectedDate == null
                    ? 'Wybierz datę'
                    : 'Data: ${_selectedDate!.day.toString().padLeft(2, "0")}.${_selectedDate!.month.toString().padLeft(2, "0")}.${_selectedDate!.year}'.split(' ')[1]),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tytuł',
                ),
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
                onChanged: (_) => _calculate(),
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
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Stawka VAT'),
                value: _selectedVatRate,
                items: _vatRates.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedVatRate = newValue;
                  });
                  _calculate();
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Proszę wybrać stawkę VAT';
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(
                  'VAT: ${_vatValue.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
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

//#region invoicedetails

class InvoiceDetailScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  Future<void> _deleteInvoice() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoicesdata.json');
      List<dynamic> invoices = [];

      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          invoices = json.decode(contents) as List<dynamic>;
        }
      }

      invoices.removeWhere((inv) =>
      inv['id'] == widget.invoice['id']);

      await file.writeAsString(json.encode(invoices));

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
        title: Text(widget.invoice['title'] ?? 'Szczegóły Faktury')
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildDetailRow('Data:', _formatDate(widget.invoice['date'])),
            _buildDetailRow('Brutto:', "${widget.invoice['gross']} zł"),
            _buildDetailRow('VAT:', "${(double.parse(widget.invoice['gross']) - double.parse(widget.invoice['net'])).toStringAsFixed(2).trim()} zł (${widget.invoice['vat']}%)"),
            _buildDetailRow('Netto:', "${widget.invoice['net']} zł"),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                // Navigate to the edit invoice screen
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => EditInvoiceScreen(invoice: widget.invoice)),
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
                      content: const Text('Czy na pewno chcesz usunąć tę fakturę?'),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Anuluj'),
                          onPressed: () => Navigator.of(context).pop(), // Close the dialog
                        ),
                        TextButton(
                          child: const Text('Usuń'),
                          onPressed: () => {
                            _deleteInvoice(),
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

//#region editinvoice
class EditInvoiceScreen extends StatefulWidget {
  final Map<String, dynamic> invoice;

  const EditInvoiceScreen({super.key, required this.invoice});

  @override
  State<EditInvoiceScreen> createState() => _EditInvoiceScreenState();
}

class _EditInvoiceScreenState extends State<EditInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime? _selectedDate;
  late TextEditingController _titleController;
  late TextEditingController _grossController;
  String? _selectedVatRate;
  double _netValue = 0.0;
  double _vatValue = 0.0;

  final List<String> _vatRates = ['23%', '8%', '5%', '0%'];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.parse(widget.invoice['date']);
    _titleController = TextEditingController(text: widget.invoice['title']);
    _grossController = TextEditingController(text: widget.invoice['gross']);
    _selectedVatRate = "${widget.invoice['vat'].toString().split('.')[0]}%";
    _calculate();
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

  void _calculate() {
    final double gross = double.tryParse(_grossController.text) ?? 0.0;
    final double vatRatePercentage = double.tryParse(_selectedVatRate!.replaceAll('%', '')) ?? 0.0;
    final double vatRate = vatRatePercentage / 100;
    setState(() {
      _netValue = gross / (1 + vatRate);
      _vatValue = gross - _netValue;
    });
  }

  Future<void> _updateInvoice() async {
    if (_formKey.currentState!.validate() && _selectedDate != null) {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/invoicesdata.json');
      List<dynamic> invoices = [];

      if (await file.exists()) {
        final contents = await file.readAsString();
        if (contents.isNotEmpty) {
          invoices = json.decode(contents) as List<dynamic>;
        }
      }

      int index = invoices.indexWhere((inv) => inv['id'] == widget.invoice['id']);
      if (index != -1) {
        invoices[index] = {
          'id': widget.invoice['id'],
          'date': _selectedDate!.toIso8601String(),
          'title': _titleController.text.trim(),
          'gross': _grossController.text.trim(),
          'vat': double.parse(_selectedVatRate!.replaceAll('%', '')),
          'net': _netValue.toStringAsFixed(2).trim(),
        };
        await file.writeAsString(json.encode(invoices));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Zaktualizowano fakturę'), action: SnackBarAction(label: 'OK', onPressed: () {})),
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
        title: const Text('Edytuj Fakturę'),
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
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tytuł'),
                validator: (value) => value == null || value.isEmpty ? 'Proszę podać tytuł' : null,
              ),
              TextFormField(
                controller: _grossController,
                decoration: const InputDecoration(labelText: 'Brutto'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculate(),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Proszę podać kwotę brutto';
                  if (double.tryParse(value) == null) return 'Proszę podać poprawną liczbę';
                  return null;
                },
              ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Stawka VAT'),
                value: _selectedVatRate,
                items: _vatRates.map((String value) => DropdownMenuItem<String>(value: value, child: Text(value))).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedVatRate = newValue;
                    _calculate();
                  });
                },
                validator: (value) => value == null || value.isEmpty ? 'Proszę wybrać stawkę VAT' : null,
              ),
              Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: Text('Netto: ${_netValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: Text('VAT: ${_vatValue.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16))),
              ElevatedButton(onPressed: _updateInvoice, child: const Text('Zapisz zmiany')),
            ],
          ),
        ),
      ),
    );
  }
}
//#endregion