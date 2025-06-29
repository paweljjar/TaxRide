import 'package:flutter/material.dart';

import 'Invoices.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent)
      ),
      home: Home()
    );
  }
}

class Home extends StatelessWidget{
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: TabBarView(
            children: [
              InvoicesScreen()
            ]
        ),
        bottomNavigationBar: Container(
          color: Theme
              .of(context)
              .primaryColor,
          child: const TabBar(
            tabs: [
              Tab(
                  icon: Icon(Icons.text_snippet),
                  text: 'Faktury'
              ),
              Tab(
                  icon: Icon(Icons.attach_money_rounded),
                  text: 'Przychód'
              ),
              Tab(
                  icon: Icon(Icons.money_off),
                  text: 'Podatki'
              ),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorPadding: EdgeInsets.all(5.0),
            indicatorColor: Colors.white,
          )
        ),
      )
    );
  }
}