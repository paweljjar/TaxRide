import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'incomes.dart';
import 'invoices.dart';

class TaxesScreen extends StatefulWidget {
  const TaxesScreen({super.key});

  @override
  State<TaxesScreen> createState() => _TaxesScreenState();
}

class _TaxesScreenState extends State<TaxesScreen> {
  bool _isLoading = true;
  double _taxToPay = 0.0;
  double _baseValue = 0.0;

  double b = 0, c = 0, d = 0, e = 0, f = 0, g = 0, h = 0;

  @override
  void initState() {
    super.initState();
    _calculateCurrentMonthTax();
  }

  Future<void> _calculateCurrentMonthTax() async {
    setState(() => _isLoading = true);

    DateTime now = DateTime.now();
    final data = await _fetchDataForMonth(now.year, now.month);

    setState(() {
      _applyCalculations(data['incomes'], data['invoices']);
      _isLoading = false;
    });
  }

  void _applyCalculations(List<Income> incomes, List<Invoice> invoices) {
    b = 0; c = 0; d = 0; e = 0; f = 0; g = 0; h = 0;

    for (var inc in incomes) {
      double grossValue = double.tryParse(inc.gross.toString().replaceAll(',', '.')) ?? 0.0;
      if (inc.source == IncomeSource.bolt) {
        inc.type == IncomeType.basic ? b += grossValue : c += grossValue;
      } else if (inc.source == IncomeSource.uber) {
        inc.type == IncomeType.basic ? d += grossValue : e += grossValue;
      } else if (inc.source == IncomeSource.freenow) {
        inc.type == IncomeType.basic ? f += grossValue : g += grossValue;
      }
    }

    for (var inv in invoices) {
      h += double.tryParse(inv.gross.replaceAll(',', '.')) ?? 0.0;
    }

    _baseValue = 0.92 * b - 0.15 * c + 0.92 * d - 0.15 * e + 0.92 * f - 0.15 * g - 0.75 * h - 184.92;

    _taxToPay = _baseValue > 0 ? _baseValue * 0.085 : 0.0;
  }

  Future<Map<String, dynamic>> _fetchDataForMonth(int year, int month) async {
    final directory = await getApplicationDocumentsDirectory();

    List<Income> filteredIncomes = [];
    final incomeFile = File('${directory.path}/incomesdata.json');
    if (await incomeFile.exists()) {
      final List<dynamic> jsonIn = json.decode(await incomeFile.readAsString());
      filteredIncomes = jsonIn
          .map((e) => Income.fromJson(e))
          .where((i) => i.date.year == year && i.date.month == month)
          .toList();
    }

    List<Invoice> filteredInvoices = [];
    final invoiceFile = File('${directory.path}/invoicesdata.json');
    if (await invoiceFile.exists()) {
      final List<dynamic> jsonInv = json.decode(await invoiceFile.readAsString());
      filteredInvoices = jsonInv
          .map((e) => Invoice.fromJson(e))
          .where((i) => i.date.year == year && i.date.month == month)
          .toList();
    }

    return {'incomes': filteredIncomes, 'invoices': filteredInvoices};
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final currentMonthName = DateFormat('MMMM yyyy', 'pl_PL').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Podatki', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _calculateCurrentMonthTax,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildStatusCard(currentMonthName, primaryColor),
            const SizedBox(height: 20),
            _buildDetailsSection(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHistory(),
        backgroundColor: primaryColor,
        child: const Icon(Icons.history, color: Colors.white),
      ),
    );
  }

  Widget _buildStatusCard(String month, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Text(month.toUpperCase(), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('DO ZAPŁATY (RYCZAŁT)', style: TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 5),
            Text('${_taxToPay.toStringAsFixed(2)} zł',
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
          child: Text('PODSUMOWANIE SKŁADNIKÓW', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ),
        _detailRow('Przychody Bolt', b),
        _detailRow('Bonusy Bolt', c),
        _detailRow('Przychody Uber', d),
        _detailRow('Bonusy Uber', e),
        _detailRow('Przychody FreeNow', f),
        _detailRow('Bonusy FreeNow', g),
        _detailRow('Suma Faktur', h),
        const Divider(height: 30),
        _detailRow('Podstawa opodatkowania', _baseValue, isBold: true),
      ],
    );
  }

  Widget _detailRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text('${value.toStringAsFixed(2)} zł',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: value < 0 ? Colors.red : Colors.black87)),
        ],
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => _HistoryBottomSheet(
        onMonthSelected: (year, month) async {
          final data = await _fetchDataForMonth(year, month);
          setState(() {
            _applyCalculations(data['incomes'], data['invoices']);
          });
          Navigator.pop(context);
        },
      ),
    );
  }
}

class _HistoryBottomSheet extends StatelessWidget {
  final Function(int, int) onMonthSelected;

  const _HistoryBottomSheet({required this.onMonthSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const SizedBox(height: 20),
          const Text('Wybierz miesiąc', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: 12,
              itemBuilder: (context, index) {
                final date = DateTime(DateTime.now().year, DateTime.now().month - index);
                return ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: Text(DateFormat('MMMM yyyy', 'pl_PL').format(date)),
                  onTap: () => onMonthSelected(date.year, date.month),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}