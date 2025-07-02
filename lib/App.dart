import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:taxride/Incomes.dart';
import 'package:taxride/Taxes.dart';
import 'package:taxride/Invoices.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      supportedLocales: [const Locale("pl", "")],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate, // Important for iOS-style elements too
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlueAccent),
        useMaterial3: true,
      ),
      home: const Home(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with TickerProviderStateMixin {
  late InterstitialAd _interstitialAd;
  bool _isInterstitialAdReady = false;
  DateTime _lastAdShownTime = DateTime.now().subtract(const Duration(minutes: 2));
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;

      final now = DateTime.now();

      if (_isInterstitialAdReady && now.difference(_lastAdShownTime) >= const Duration(minutes: 1, seconds: 30)) {
        _showInterstitialAd();
        _lastAdShownTime = now;
      }
    });

    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-5986618711761266/6625659033',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          setState(() {
            _isInterstitialAdReady = true;
            _interstitialAd = ad;
          });
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) {
            print('InterstitialAd failed to load: $error');
          }
          _isInterstitialAdReady = false;
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_isInterstitialAdReady) {
      _interstitialAd.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          setState(() {
            _isInterstitialAdReady = false;
          });
          _loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          if (kDebugMode) {
            print('InterstitialAd failed to show: $error');
          }
          ad.dispose();
          setState(() {
            _isInterstitialAdReady = false;
          });
        },
      );

      _interstitialAd.show();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_isInterstitialAdReady) {
      _interstitialAd.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: const [
          TaxesScreen(),
          InvoicesScreen(),
          IncomesScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        color: Theme.of(context).primaryColor,
        child: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.money_off), text: 'Podatki'),
            Tab(icon: Icon(Icons.text_snippet), text: 'Faktury'),
            Tab(icon: Icon(Icons.attach_money_rounded), text: 'Przychód'),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorPadding: EdgeInsets.all(5.0),
          indicatorColor: Colors.white,
        ),
      ),
    );
  }
}
