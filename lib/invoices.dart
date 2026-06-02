import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class Invoice {
  final String id;
  final DateTime date;
  final String title;
  final String gross;
  final double vat;
  final String net;

  Invoice({
    required this.id,
    required this.date,
    required this.title,
    required this.gross,
    required this.vat,
    required this.net,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String,
      gross: json['gross'] as String,
      vat: (json['vat'] as num).toDouble(),
      net: json['net'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'title': title,
      'gross': gross,
      'vat': vat,
      'net': net,
    };
  }
}

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<StatefulWidget> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadInvoices();
  }

  Future<File> _getLocalFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/invoicesdata.json');
  }

  Future<void> _loadInvoices() async {
    try {
      final file = await _getLocalFile();
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonData = json.decode(contents);

        setState(() {
          _invoices = jsonData
              .map((item) => Invoice.fromJson(item as Map<String, dynamic>))
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

  Future<void> _saveInvoices(List<Invoice> newInvoices) async {
    try {
      final file = await _getLocalFile();

      final jsonData = newInvoices.map((i) => i.toJson()).toList();
      final String jsonString = json.encode(jsonData);

      await file.writeAsString(jsonString);

      setState(() {
        _invoices = newInvoices;
      });
    } catch (e) {
      debugPrint("Saving error: $e");
    }
  }

  Future<void> _editInvoice(String oldId, Invoice updatedInvoice) async {
    final index = _invoices.indexWhere((inv) => inv.id == oldId);
    if (index != -1) {
      final updatedList = List<Invoice>.from(_invoices);
      updatedList[index] = updatedInvoice;
      await _saveInvoices(updatedList);
    }
  }

  Future<void> _deleteInvoice(String id) async {
    final index = _invoices.indexWhere((inv) => inv.id == id);
    final deletedInvoice = _invoices[index];
    final updatedInvoices = _invoices.where((inv) => inv.id != id).toList();
    await _saveInvoices(updatedInvoices);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Faktura została usunięta'),
        action: SnackBarAction(
          label: 'COFNIJ',
          onPressed: () {
            final restoredInvoices = List<Invoice>.from(_invoices);
            restoredInvoices.insert(index, deletedInvoice);
            _saveInvoices(restoredInvoices);
          },
        ),
      ),
    );
  }

  Map<int, Map<int, List<Invoice>>> _getNestedGroupedInvoices() {
    final sortedInvoices = List<Invoice>.from(_invoices)
      ..sort((a, b) => a.date.compareTo(b.date));

    final Map<int, Map<int, List<Invoice>>> groups = {};

    for (var invoice in sortedInvoices) {
      final year = invoice.date.year;
      final month = invoice.date.month;

      if (!groups.containsKey(year)) {
        groups[year] = {};
      }
      if (!groups[year]!.containsKey(month)) {
        groups[year]![month] = [];
      }
      groups[year]![month]!.add(invoice);
    }
    return groups;
  }

  String _getMonthName(int month) {
    final dateTime = DateTime(2000, month);
    return DateFormat('MMMM', 'pl_PL').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final nestedGroups = _getNestedGroupedInvoices();
    final years = nestedGroups.keys.toList()..sort((a, b) => a.compareTo(b));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje Faktury'),
        centerTitle: true,
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? const Center(child: Text('Brak faktur'))
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
                        final invoices = monthsMap[month]!;
                        return ExpansionTile(
                          title: Text(
                            _getMonthName(month).toUpperCase(),
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          children: invoices.map((invoice) {
                            return Dismissible(
                              key: Key(invoice.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              onDismissed: (direction) => _deleteInvoice(invoice.id),
                              child: ListTile(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => InvoiceDetailScreen(
                                        invoice: invoice,
                                        onDelete: () => _deleteInvoice(invoice.id),
                                        onEdit: (updated) => _editInvoice(invoice.id, updated),
                                      ),
                                    ),
                                  );
                                },
                                leading: const Icon(Icons.description_outlined),
                                title: Text(
                                  invoice.title,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                subtitle: Text(
                                  'Data: ${DateFormat('dd.MM.yyyy').format(invoice.date)}',
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${invoice.gross} zł',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const Text('brutto', style: TextStyle(fontSize: 10)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddInvoiceScreen(
                onSave: (newInvoice) {
                  final updatedInvoices = List<Invoice>.from(_invoices)
                    ..add(newInvoice);
                  _saveInvoices(updatedInvoices);
                },
              ),
            ),
          );
          if (result == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Faktura została dodana')),
            );
          }
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class InvoiceDetailScreen extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback onDelete;
  final Function(Invoice) onEdit;

  const InvoiceDetailScreen({
    super.key,
    required this.invoice,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final double grossVal = double.tryParse(invoice.gross.replaceAll(',', '.')) ?? 0;
    final double netVal = double.tryParse(invoice.net.replaceAll(',', '.')) ?? 0;
    final String vatVal = (grossVal - netVal).toStringAsFixed(2);

    final String formattedDate = DateFormat('dd.MM.yyyy').format(invoice.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Szczegóły Faktury'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddInvoiceScreen(
                    invoiceToEdit: invoice,
                    onSave: (updatedInvoice) {
                      onEdit(updatedInvoice);
                      Navigator.pop(context);
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Usuń fakturę'),
                  content: const Text('Czy na pewno chcesz usunąć tę fakturę?'),
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
                      invoice.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const Divider(height: 32),
                    _buildDetailRow('Data wystawienia', formattedDate),
                    _buildDetailRow('Kwota Brutto', '${invoice.gross} zł', isBold: true),
                    _buildDetailRow('Kwota Netto', '${invoice.net} zł'),
                    _buildDetailRow('Stawka VAT', '${invoice.vat.toInt()}%'),
                    _buildDetailRow(
                      'Wartość VAT',
                      '$vatVal zł',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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

class AddInvoiceScreen extends StatefulWidget {
  final Function(Invoice) onSave;
  final Invoice? invoiceToEdit;

  const AddInvoiceScreen({
    super.key,
    required this.onSave,
    this.invoiceToEdit,
  });

  @override
  State<AddInvoiceScreen> createState() => _AddInvoiceScreenState();
}

class _AddInvoiceScreenState extends State<AddInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _grossController = TextEditingController();
  final _vatAmountController = TextEditingController();
  final _netController = TextEditingController();
  double _selectedVat = 23.0;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.invoiceToEdit != null) {
      final inv = widget.invoiceToEdit!;
      _titleController.text = inv.title;
      _grossController.text = inv.gross;
      _selectedVat = inv.vat;
      _selectedDate = inv.date;
      WidgetsBinding.instance.addPostFrameCallback((_) => _calculateValues());
    }
  }

  Future<void> _presentDatePicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
    }
  }

  void _calculateValues() {
    final double gross = double.tryParse(_grossController.text.replaceAll(',', '.')) ?? 0;

    final double net = gross / (1 + (_selectedVat / 100));
    final double vatAmount = gross - net;

    setState(() {
      _netController.text = net.toStringAsFixed(2);
      _vatAmountController.text = vatAmount.toStringAsFixed(2);
    });
  }

  void _submitData() {
    if (_grossController.text.isNotEmpty) {
      _calculateValues();
    }

    if (_formKey.currentState!.validate()) {
      final newInvoice = Invoice(
        id: widget.invoiceToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        date: _selectedDate,
        title: _titleController.text,
        gross: _grossController.text,
        vat: _selectedVat,
        net: _netController.text,
      );

      widget.onSave(newInvoice);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoiceToEdit == null ? 'Dodaj Fakturę' : 'Edytuj Fakturę'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tytuł/Nr faktury'),
                validator: (value) => value!.isEmpty ? 'Wpisz tytuł' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _grossController,
                decoration: const InputDecoration(labelText: 'Kwota Brutto'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
                ],
                validator: (value) => value!.isEmpty ? 'Wpisz kwotę' : null,
                onChanged: (value) => _calculateValues(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<double>(
                value: _selectedVat,
                decoration: const InputDecoration(labelText: 'Stawka VAT (%)'),
                items: [0.0, 5.0, 8.0, 23.0].map((double value) {
                  return DropdownMenuItem<double>(
                    value: value,
                    child: Text('${value.toInt()}%'),
                  );
                }).toList(),
                onChanged: (double? newValue) {
                  setState(() {
                    _selectedVat = newValue!;
                    _calculateValues();
                  });
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text("Data wystawienia: ${_selectedDate.toString().substring(0, 10)}"),
                trailing: const Icon(Icons.calendar_today),
                onTap: _presentDatePicker,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _vatAmountController,
                decoration: const InputDecoration(
                  labelText: 'Wyliczony VAT',
                  filled: true,
                ),
                readOnly: true,
              ),
              TextFormField(
                controller: _netController,
                decoration: const InputDecoration(
                  labelText: 'Kwota Netto (wyliczona)',
                  filled: true,
                ),
                readOnly: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                child: Text(widget.invoiceToEdit == null ? 'Zapisz fakturę' : 'Zapisz zmiany'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}