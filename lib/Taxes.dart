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

    final String invoicesJson = await invoicesFile.readAsString();
    final String incomesJson = await incomesFile.readAsString();

    final List<dynamic> invoicesData = json.decode(invoicesJson);
    final List<dynamic> incomesData = json.decode(incomesJson);

    double b = 0.0; // income from bolt
    double c = 0.0; // bonus from bolt
    double d = 0.0; // income from uber
    double e = 0.0; // bonus from uber
    double f = 0.0; // income from freenow
    double g = 0.0; // bonus from freenow
    double h = 0.0; // sum of invoices

    for (var income in incomesData) {
      DateTime incomeDate = DateTime.parse(income['date']);
      if (incomeDate.month == _currentMonth && incomeDate.year == _currentYear) {
        if (income['type'] == 'Przychód' && income['source'] == 'Bolt') {
          b += double.parse(income['gross']);
        } else if (income['type'] == 'bonus' && income['source'] == 'Bolt') {
          c += double.parse(income['gross']);
        } else if (income['type'] == 'Przychód' && income['source'] == 'Uber') {
          d += double.parse(income['gross']);
        } else if (income['type'] == 'bonus' && income['source'] == 'Uber') {
          e += double.parse(income['gross']);
        } else if (income['type'] == 'Przychód' && income['source'] == 'FreeNow') {
          f += double.parse(income['gross']);
        } else if (income['type'] == 'bonus' && income['source'] == 'FreeNow') {
          g += double.parse(income['gross']);
        }
      }
    }

    for (var invoice in invoicesData) {
      DateTime invoiceDate = DateTime.parse(invoice['date']);
      if (invoiceDate.month == _currentMonth && invoiceDate.year == _currentYear) {
        h += double.parse(invoice['net']);
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
        onPressed: () {
          _calculateTaxes();
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.history, color: Colors.white),
      ),
    );
  }
}

//#endregion