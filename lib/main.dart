import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:taxride/home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  initializeDateFormatting('pl_PL', null).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaxRide',
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
          useMaterial3: true
      ),
      debugShowCheckedModeBanner: false,
      home: const HomePage(),
    );
  }
}