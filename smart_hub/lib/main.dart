import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:provider/provider.dart';
import 'package:smart_hub/Main/BLE/ble_ui.dart';
import 'package:smart_hub/Main/home/home_screen.dart';
import 'package:smart_hub/Main/loading_screen.dart';

import '../../Components/provider.dart';
import 'Main/Support/support.dart';

late final StreamSubscription<ConnectionStateUpdate> connectionNUM;
late final DiscoveredDevice connectedDevice;
late final QualifiedCharacteristic characteristic;


void main() {
  runApp(
    /*  Phoenix Package used to restart the app https://pub.dev/packages/flutter_phoenix */
    Phoenix(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ScreenDataProvider()),
        ],
        child: const SmartHUB(),
      ),
    ),
  );
}

class SmartHUB extends StatelessWidget {
  const SmartHUB({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        /* This screen is responsible for loading all packages used before the app launch */
        initialRoute: welcome_loading_screen.id,
        routes: {
          welcome_loading_screen.id: (context) =>
              const welcome_loading_screen(),
          ble_ui_screen.id: (context) => const ble_ui_screen(),
          HomeScreen.id: (context) => HomeScreen(
                connectionNUM: connectionNUM,
                connectedDevice: connectedDevice,
                characteristic: characteristic,
              ),
          support_screen.id: (context) => const support_screen(),
        });
  }
}
