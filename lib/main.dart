import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'App.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MobileAds.instance.initialize();

  RequestConfiguration requestConfiguration = RequestConfiguration(
    testDeviceIds: ['5a33757b-cd56-4499-91ad-5804ad52a488']
  );

  MobileAds.instance.updateRequestConfiguration(requestConfiguration);

  runApp(const App());
}