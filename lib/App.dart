import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:taxride/Incomes.dart';
import 'package:taxride/Taxes.dart';

import "package:google_mobile_ads/google_mobile_ads.dart";

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
      home: Home(),
      debugShowCheckedModeBanner: false
    );
  }
}

class Home extends StatefulWidget{
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home>{
  late InterstitialAd _interstitialAd;
  bool _isInterstitialAdReady = false;

  @override
  void initState() {
    super.initState();

    InterstitialAd.load(
      adUnitId: 'ca-app-pub-5986618711761266/6625659033',
      request: AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _isInterstitialAdReady = true;
            _interstitialAd = ad;
          });
        },
        onAdFailedToLoad: (error) {
          if(kDebugMode){
            print('InterstitialAd failed to load: $error');
          }
          _isInterstitialAdReady = false;
        },
      )
    );
  }

  @override
  void dispose(){
    if(_isInterstitialAdReady){
      _interstitialAd.dispose();
    }
    super.dispose();
  }

  void _showInterstitialAd() {
    if(_isInterstitialAdReady){
      _interstitialAd.show();
      _interstitialAd.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          setState(() {
            _isInterstitialAdReady = false;
          });
          InterstitialAd.load(
              adUnitId: 'ca-app-pub-5986618711761266/6625659033',
              request: AdRequest(),
              adLoadCallback: InterstitialAdLoadCallback(
                onAdLoaded: (ad) {
                  setState(() {
                    _isInterstitialAdReady = true;
                    _interstitialAd = ad;
                  });
                },
                onAdFailedToLoad: (error) {
                  if(kDebugMode){
                    print('InterstitialAd failed to load: $error');
                  }
                  _isInterstitialAdReady = false;
                },
              )
          );
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          if(kDebugMode){
            print('InterstitialAd failed to show: $error');
          }
          ad.dispose();
          setState(() {
            _isInterstitialAdReady = false;
          });
        }
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: TabBarView(
            children: [
              TaxesScreen(),
              InvoicesScreen(),
              IncomesScreen()
            ]
        ),
        bottomNavigationBar: Container(
          color: Theme
              .of(context)
              .primaryColor,
          child: const TabBar(
            tabs: [
              Tab(
                  icon: Icon(Icons.money_off),
                  text: 'Podatki'
              ),
              Tab(
                  icon: Icon(Icons.text_snippet),
                  text: 'Faktury'
              ),
              Tab(
                  icon: Icon(Icons.attach_money_rounded),
                  text: 'Przychód'
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