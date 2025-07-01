import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

//#region taxes

class TaxesScreen extends StatefulWidget {
  const TaxesScreen({super.key});

  @override
  State<TaxesScreen> createState() => _TaxesScreenState();
}

class _TaxesScreenState extends State<TaxesScreen> {
  double _tax = 0.0;
  double _base = 0.0;

  final int _currentMonth = DateTime.now().month;
  final int _currentYear = DateTime.now().year;

  Future<void> _calculateTaxes() async {
    final directory = await getApplicationDocumentsDirectory();
    final invoicesFile = File('${directory.path}/invoicesdata.json');
    final incomesFile = File('${directory.path}/incomesdata.json');

    double b = 0.0; // income from bolt
    double c = 0.0; // bonus from bolt
    double d = 0.0; // income from uber
    double e = 0.0; // bonus from uber
    double f = 0.0; // income from freenow
    double g = 0.0; // bonus from freenow
    double h = 0.0; // sum of invoices

    if(incomesFile.existsSync()){
      final String incomesJson = await incomesFile.readAsString();
      final List<dynamic> incomesData = json.decode(incomesJson);

      for (var income in incomesData) {
        DateTime incomeDate = DateTime.parse(income['date']);
        if (incomeDate.month == _currentMonth && incomeDate.year == _currentYear) {
          if (income['type'] == 'Przychód' && income['source'] == 'Bolt') {
            b += double.parse(income['gross']);
          } else if (income['type'] == 'Bonus' && income['source'] == 'Bolt') {
            c += double.parse(income['gross']);
          } else if (income['type'] == 'Przychód' && income['source'] == 'Uber') {
            d += double.parse(income['gross']);
          } else if (income['type'] == 'Bonus' && income['source'] == 'Uber') {
            e += double.parse(income['gross']);
          } else if (income['type'] == 'Przychód' && income['source'] == 'FreeNow') {
            f += double.parse(income['gross']);
          } else if (income['type'] == 'Bonus' && income['source'] == 'FreeNow') {
            g += double.parse(income['gross']);
          }
        }
      }
    }

    if(invoicesFile.existsSync()){
      final String invoicesJson = await invoicesFile.readAsString();
      final List<dynamic> invoicesData = json.decode(invoicesJson);

      for (var invoice in invoicesData) {
        DateTime invoiceDate = DateTime.parse(invoice['date']);
        if (invoiceDate.month == _currentMonth && invoiceDate.year == _currentYear) {
          h += double.parse(invoice['net']);
        }
      }
    }

    final calculatedBase = 0.92 * b - 0.15 * c + 0.92 * d - 0.15 * e + 0.92 * f - 0.15 * g - 0.75 * h - 184.92;

    setState(() {
      _base = calculatedBase;
      _tax = _base * 0.085;
    });
  }

  @override
  void initState() {
    super.initState();
    _calculateTaxes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.only(
            left: 16.0,
            right: 16.0
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  "Podatek za ten miesiąc",
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold)
              ),
              Text(
                  "${_tax.toStringAsFixed(2)} zł",
                  style: const TextStyle(fontSize: 25)
              ),
              Text(
                  "Podstawa obliczenia podatku",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w300)
              ),
              Text(
                  "${_base.toStringAsFixed(2)} zł",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w100)
              )
            ]
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PreviousTaxesScreen()),
          );
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.history, color: Colors.white),
      ),
    );
  }
}

//#endregion

//#region previoustaxes

class PreviousTaxesScreen extends StatefulWidget {
  const PreviousTaxesScreen({super.key});

  @override
  State<PreviousTaxesScreen> createState() => _PreviousTaxesScreenState();
}

class _PreviousTaxesScreenState extends State<PreviousTaxesScreen> {
  Map<String, Map<String, double>> _monthlyTaxes = {};

  @override
  void initState() {
    super.initState();
    _calculateAllMonthlyTaxes();
  }

  Future<void> _calculateAllMonthlyTaxes() async {
    final directory = await getApplicationDocumentsDirectory();
    final invoicesFile = File('${directory.path}/invoicesdata.json');
    final incomesFile = File('${directory.path}/incomesdata.json');

    if (!await invoicesFile.exists() || !await incomesFile.exists()) {
      // Handle case where files don't exist
      return;
    }

    final String invoicesJson = await invoicesFile.readAsString();
    final String incomesJson = await incomesFile.readAsString();

    final List<dynamic> invoicesData = json.decode(invoicesJson);
    final List<dynamic> incomesData = json.decode(incomesJson);

    Map<String, Map<String, double>> monthlyData = {};

    // Process incomes
    for (var income in incomesData) {
      DateTime incomeDate = DateTime.parse(income['date']);
      String monthYearKey = "${incomeDate.month}-${incomeDate.year}";
      monthlyData.putIfAbsent(monthYearKey, () => {'b': 0.0, 'c': 0.0, 'd': 0.0, 'e': 0.0, 'f': 0.0, 'g': 0.0, 'h': 0.0, 'tax': 0.0, 'base': 0.0});

      if (income['type'] == 'Przychód' && income['source'] == 'Bolt') {
        monthlyData[monthYearKey]!['b'] = (monthlyData[monthYearKey]!['b'] ?? 0) + double.parse(income['gross']);
      } else if (income['type'] == 'Bonus' && income['source'] == 'Bolt') {
        monthlyData[monthYearKey]!['c'] = (monthlyData[monthYearKey]!['c'] ?? 0) + double.parse(income['gross']);
      } else if (income['type'] == 'Przychód' && income['source'] == 'Uber') {
        monthlyData[monthYearKey]!['d'] = (monthlyData[monthYearKey]!['d'] ?? 0) + double.parse(income['gross']);
      } else if (income['type'] == 'Bonus' && income['source'] == 'Uber') {
        monthlyData[monthYearKey]!['e'] = (monthlyData[monthYearKey]!['e'] ?? 0) + double.parse(income['gross']);
      } else if (income['type'] == 'Przychód' && income['source'] == 'FreeNow') {
        monthlyData[monthYearKey]!['f'] = (monthlyData[monthYearKey]!['f'] ?? 0) + double.parse(income['gross']);
      } else if (income['type'] == 'Bonus' && income['source'] == 'FreeNow') {
        monthlyData[monthYearKey]!['g'] = (monthlyData[monthYearKey]!['g'] ?? 0) + double.parse(income['gross']);
      }
    }

    // Process invoices
    for (var invoice in invoicesData) {
      DateTime invoiceDate = DateTime.parse(invoice['date']);
      String monthYearKey = "${invoiceDate.month}-${invoiceDate.year}";
      monthlyData.putIfAbsent(monthYearKey, () => {'b': 0.0, 'c': 0.0, 'd': 0.0, 'e': 0.0, 'f': 0.0, 'g': 0.0, 'h': 0.0, 'tax': 0.0, 'base': 0.0});
      monthlyData[monthYearKey]!['h'] = (monthlyData[monthYearKey]!['h'] ?? 0) + double.parse(invoice['net']);
    }

    // Calculate tax and base for each month
    monthlyData.forEach((key, value) {
      final b = value['b'] ?? 0.0;
      final c = value['c'] ?? 0.0;
      final d = value['d'] ?? 0.0;
      final e = value['e'] ?? 0.0;
      final f = value['f'] ?? 0.0;
      final g = value['g'] ?? 0.0;
      final h = value['h'] ?? 0.0;

      final calculatedBase = 0.92 * b - 0.15 * c + 0.92 * d - 0.15 * e + 0.92 * f - 0.15 * g - 0.75 * h - 184.92;
      final calculatedTax = calculatedBase * 0.085;

      monthlyData[key]!['base'] = calculatedBase;
      monthlyData[key]!['tax'] = calculatedTax;
    });

    // Sort the results by year and then by month
    var sortedKeys = monthlyData.keys.toList()
      ..sort((a, b) {
        var partsA = a.split('-').map(int.parse).toList();
        var partsB = b.split('-').map(int.parse).toList();
        return partsA[1] == partsB[1] ? partsA[0].compareTo(partsB[0]) : partsA[1].compareTo(partsB[1]);
      });
    _monthlyTaxes = {for (var k in sortedKeys) k: monthlyData[k]!};
    setState(() {});
  }

  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Icon(Icons.arrow_back_ios)
        ),
      ),
      body: _monthlyTaxes.isEmpty
          ? Center(child: Text("Brak danych do wyświetlenia."))
          : ListView.builder(
        itemCount: _monthlyTaxes.length,
        itemBuilder: (context, index) {
          String monthYearKey = _monthlyTaxes.keys.elementAt(index);
          Map<String, double> taxData = _monthlyTaxes[monthYearKey]!;
          var parts = monthYearKey.split('-');
          String displayMonthYear = "${parts[0]}/${parts[1]}"; // Format as MM/YYYY

          return Card(
            margin: EdgeInsets.all(8.0),
            child: ListTile(
              title: Text("Miesiąc: $displayMonthYear", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text("Podstawa: ${taxData['base']?.toStringAsFixed(2) ?? '-184.92'} zł"),
                  Text("Podatek: ${taxData['tax']?.toStringAsFixed(2) ?? '-15.72'} zł"),
                ],
              ),
            ),
          );
        },
      )
    );
  }
}

//#endregion