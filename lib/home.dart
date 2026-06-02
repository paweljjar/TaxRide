import 'package:flutter/material.dart';
import 'package:taxride/incomes.dart';
import 'package:taxride/invoices.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: [
          Center(
            child: Text('Taxes'),
          ),
          InvoicesScreen(),
          IncomesScreen()
        ],
      ),
      bottomNavigationBar: Container(
        color: Theme.of(context).primaryColor,
        child: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorPadding: EdgeInsets.all(5.0),
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.money_off), text: 'Podatki'),
            Tab(icon: Icon(Icons.text_snippet), text: 'Faktury'),
            Tab(icon: Icon(Icons.attach_money_rounded), text: 'Przychód'),
          ],
        )
      )
    );
  }
}