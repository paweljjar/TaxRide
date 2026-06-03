import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class InvoiceItem {
  final String name;
  final double quantity;
  final double netPrice;
  final double vatRate;
  InvoiceItem({
    required this.name,
    required this.quantity,
    required this.netPrice,
    required this.vatRate,
  });

  double get totalNet => netPrice * quantity;
  double get vatAmount => totalNet * (vatRate / 100);
  double get totalGross => totalNet + vatAmount;

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'netPrice': netPrice,
    'vatRate': vatRate,
  };

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
    name: json['name'],
    quantity: (json['quantity'] as num).toDouble(),
    netPrice: (json['netPrice'] as num).toDouble(),
    vatRate: (json['vatRate'] as num).toDouble(),
  );
}

class Invoice {
  final String id;
  final DateTime date;
  final String title;
  final List<InvoiceItem> items;

  Invoice({
    required this.id,
    required this.date,
    required this.title,
    required this.items,
  });

  double get totalNet => items.fold(0, (sum, item) => sum + item.totalNet);
  double get totalVat => items.fold(0, (sum, item) => sum + item.vatAmount);
  double get totalGross => items.fold(0, (sum, item) => sum + item.totalGross);

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'title': title,
    'items': items.map((i) => i.toJson()).toList(),
  };

  factory Invoice.fromJson(Map<String, dynamic> json) => Invoice(
    id: json['id'],
    date: DateTime.parse(json['date']),
    title: json['title'],
    items: (json['items'] as List)
        .map((i) => InvoiceItem.fromJson(i as Map<String, dynamic>))
        .toList(),
  );
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
    if (index == -1) return;

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
      ..sort((a, b) => b.date.compareTo(a.date)); // Sortowanie od najnowszych

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
    final years = nestedGroups.keys.toList()..sort((a, b) => b.compareTo(a));

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
          final months = monthsMap.keys.toList()..sort((a, b) => b.compareTo(a));

          return ExpansionTile(
            initiallyExpanded: yearIndex == 0,
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
                            '${invoice.totalGross.toStringAsFixed(2)} zł', // ZMIANA: używamy totalGross
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${invoice.items.length} poz.', // Opcjonalnie: liczba pozycji
                            style: const TextStyle(fontSize: 10),
                          ),
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
          // Tu nastąpi zmiana w następnym kroku - AddInvoiceScreen
          await Navigator.push(
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
                    const SizedBox(height: 20),

                    // SEKCJA POZYCJI
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pozycje:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...invoice.items.map((item) => _buildItemRow(item)).toList(),

                    const Divider(height: 32),

                    // PODSUMOWANIE
                    _buildDetailRow('Suma Netto', '${invoice.totalNet.toStringAsFixed(2)} zł'),
                    _buildDetailRow('Suma VAT', '${invoice.totalVat.toStringAsFixed(2)} zł'),
                    _buildDetailRow(
                        'RAZEM Brutto',
                        '${invoice.totalGross.toStringAsFixed(2)} zł',
                        isBold: true
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

  // Pomocniczy widget dla pojedynczego produktu na liście
  Widget _buildItemRow(InvoiceItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(item.name, style: const TextStyle(fontSize: 14)),
          ),
          Expanded(
            flex: 1,
            child: Text('${item.quantity.toStringAsFixed(0)} szt.',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            flex: 2,
            child: Text('${item.totalGross.toStringAsFixed(2)} zł',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? Colors.blueAccent : Colors.black87,
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

  // Lista pozycji na fakturze
  List<InvoiceItem> _items = [];
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.invoiceToEdit != null) {
      _titleController.text = widget.invoiceToEdit!.title;
      _selectedDate = widget.invoiceToEdit!.date;
      _items = List.from(widget.invoiceToEdit!.items); // Kopiujemy listę pozycji
    }
  }

  // Obliczanie sum na bieżąco dla podglądu w formularzu
  double get _totalNet => _items.fold(0, (sum, item) => sum + item.totalNet);
  double get _totalGross => _items.fold(0, (sum, item) => sum + item.totalGross);

  void _addItem() {
    showDialog(
      context: context,
      builder: (ctx) => _ItemDialog(
        onAdd: (newItem) {
          setState(() {
            _items.add(newItem);
          });
        },
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
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

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      if (_items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dodaj przynajmniej jeden produkt!')),
        );
        return;
      }

      final newInvoice = Invoice(
        id: widget.invoiceToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        date: _selectedDate,
        title: _titleController.text,
        items: _items,
      );

      widget.onSave(newInvoice);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoiceToEdit == null ? 'Nowa Faktura' : 'Edytuj Fakturę'),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Kontrahent / Numer faktury',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => value!.isEmpty ? 'Wpisz nazwę' : null,
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    tileColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    title: Text("Data: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}"),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: _presentDatePicker,
                  ),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Pozycje na fakturze",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add),
                        label: const Text("Dodaj produkt"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // LISTA PRODUKTÓW
                  if (_items.isEmpty)
                    const Center(child: Text("Brak produktów na liście"))
                  else
                    ..._items.asMap().entries.map((entry) {
                      int idx = entry.key;
                      InvoiceItem item = entry.value;
                      return Card(
                        child: ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            "${item.quantity.toStringAsFixed(0)} szt. x ${item.netPrice.toStringAsFixed(2)} zł (VAT ${item.vatRate.toInt()}%)",
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("${item.totalGross.toStringAsFixed(2)} zł",
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => _removeItem(idx),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),

            // PODSUMOWANIE NA DOLE
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Suma Brutto:", style: TextStyle(fontSize: 16)),
                      Text("${_totalGross.toStringAsFixed(2)} zł",
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _submitData,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(widget.invoiceToEdit == null ? 'ZAPISZ FAKTURĘ' : 'ZAPISZ ZMIANY'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemDialog extends StatefulWidget {
  final Function(InvoiceItem) onAdd;
  const _ItemDialog({required this.onAdd});

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _nameController = TextEditingController();
  final _netPriceController = TextEditingController();
  final _quantityController = TextEditingController(text: "1");
  double _selectedVat = 23.0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Dodaj produkt/usługę"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Nazwa produktu"),
            ),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Ilość"),
            ),
            TextField(
              controller: _netPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}'))],
              decoration: const InputDecoration(labelText: "Cena netto (jednostkowa)"),
            ),
            DropdownButtonFormField<double>(
              value: _selectedVat,
              decoration: const InputDecoration(labelText: "VAT %"),
              items: [23.0, 8.0, 5.0, 0.0].map((v) =>
                  DropdownMenuItem(value: v, child: Text("${v.toInt()}%"))
              ).toList(),
              onChanged: (val) => setState(() => _selectedVat = val!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("ANULUJ")),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty && _netPriceController.text.isNotEmpty) {
              final item = InvoiceItem(
                name: _nameController.text,
                quantity: double.tryParse(_quantityController.text.replaceAll(',', '.')) ?? 1,
                netPrice: double.tryParse(_netPriceController.text.replaceAll(',', '.')) ?? 0,
                vatRate: _selectedVat,
              );
              widget.onAdd(item);
              Navigator.pop(context);
            }
          },
          child: const Text("DODAJ"),
        ),
      ],
    );
  }
}