import 'dart:async';

import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_hub/Main/BLE/ble_ui.dart';

import '../Components/alerts.dart';
import '../Components/ble_alerts.dart';
import '../Constants/AnimatedColors.dart';
import '../Constants/ble_constants.dart';
import '../Constants/version.dart';
import 'home/home_screen.dart';

class welcome_loading_screen extends StatefulWidget {
  static String id = 'welcome_loading_screen';
  const welcome_loading_screen({super.key});

  @override
  State<welcome_loading_screen> createState() => _welcome_loading_screenState();
}

class _welcome_loading_screenState extends State<welcome_loading_screen>
    with SingleTickerProviderStateMixin {
  double batteryLevel =
      0.0; /* The battery level is used in the loading screen which has the animation of loading percentage */
  bool isGlobalVariableTrue =
      false; /* holds the state of the battery loading percentage if it was >75 then it will be true to change the animation to another text */
  bool blePermissionGranted =
      false; /* This variable holds the state of the permissions required */

  late AnimationController _controller;
  late Animation<double> _animation;

  late final FlutterReactiveBle
      flutterReactiveBle; /* This variable used to save info about the BLE device*/
  bool isScanning =
      false; /* This variable used to know the state of the BLE whether it's scanning the surrounded devices or not */
  late StreamSubscription<DiscoveredDevice>
      _scanStream; /* Steam for saving the scanned devices */
  final List<DiscoveredDevice> _foundDevices =
      []; /* Saves the scanned devices */
  late DiscoveredDevice
      _connectedDevice; /* If found the required device then I will save it in this variable */
  late StreamSubscription<ConnectionStateUpdate>
      _connection; /* Has some info about the connected device */
  late QualifiedCharacteristic
      _Characteristic; /* Saves the characteristics of the connected device */

  bool _isConnected =
      false; /* Checks whether the mobile is already connected to the power bank or not */
  late String SavedDeviceID; /* Saving device ID */

  /* Local storage  */
  late final SharedPreferences prefs;

  /// -------------------------Functions---------------------------------*
/*
  Title: Package init
  Description: Initializing everything at first as well as checks on
               previous connected device if it was found again then
                just re-connect to it again
 */
  Future<void> initPackage() async {
    flutterReactiveBle = FlutterReactiveBle();
    prefs = await SharedPreferences.getInstance();
    // Check for Bluetooth and location permissions
    await _checkAndRequestPermissions();
    await getFromLocalStorage();
  }

  /// -------------------------------------------------------------------*
  /*
  Title: Permission checker
  Description: checks if the required permission are given
 */
  Future<void> _checkAndRequestPermissions() async {
    // Check and request Bluetooth and location permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location
    ].request();

    // Check the status of each permission
    if (statuses[Permission.bluetoothScan]?.isGranted == true &&
        statuses[Permission.bluetoothConnect]?.isGranted == true &&
        statuses[Permission.location]?.isGranted == true) {
      print('All required permissions granted.');
      blePermissionGranted = true;
    } else {
      print('Bluetooth and/or location permission denied.');
      errorCheck(context, 'BLE'); // Handle the case where permission is denied
      blePermissionGranted = false;
    }
  }

  /// -------------------------------------------------------------------*
  /*
  Title: Animation
  Description: This function makes the animation of the battery
 */
  void BatteryAnimation() {
    // Initialize the animation controller
    _controller = AnimationController(
      duration:
          const Duration(seconds: 6), // Duration for one full battery cycle
      vsync: this,
    );

    // Setup a tween for the battery level to animate from 0 to 1
    _animation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {
          batteryLevel =
              _animation.value; // Update batteryLevel as animation progresses

          // Once the battery level reaches 100%, navigate to the Bluetooth screen
          if (batteryLevel == 1 &&
              blePermissionGranted == true &&
              _isConnected == false) {
            Navigator.pushReplacementNamed(context, ble_ui_screen.id);
          } /* In case the device was connected to another module then jump to the home screen */
          else if (batteryLevel == 1 &&
              blePermissionGranted == true &&
              _isConnected == true) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  connectionNUM: _connection,
                  connectedDevice: _connectedDevice,
                  characteristic: _Characteristic,
                ),
              ),
            );
          } else if (batteryLevel == 1 && blePermissionGranted == false) {
            permissionsError(context, 'BLE_PERM');
          }
          /* If the battery level exceeds a certain level then it will display another text */
          if (batteryLevel >= 0.75) {
            isGlobalVariableTrue = true;
          }
        });
      });

    // Start the animation, moving from 0 to 1 (0% to 100%) once
    _controller.forward();
  }

  // Function to determine battery color based on the battery level
  Color getBatteryColor(double batteryLevel) {
    if (batteryLevel <= 0.5) {
      return Colors.red; // Battery level less than or equal to 50% is red
    } else if (batteryLevel <= 0.8) {
      return Colors.orange; // Between 50% and 80%, the color is orange
    } else {
      return Colors.green; // Above 80%, the color is green
    }
  }

  /*
  Title: Local Storage
  Description: This function uses shared preference package to get some information
               about the last connected device
 */
  Future<void> getFromLocalStorage() async {
    SavedDeviceID =
        prefs.getString('ConnectedDevice') ?? 'null'; // save the device id
    if (SavedDeviceID != 'null') {
      startScan();
    }
  }

  /*
  Title: Local Storage
  Description: This function Connects to the given device in case it was found
 */
  Future<void> _connectToDevice(DiscoveredDevice device) async {
    setState(() {
      _isConnected = false;
    });

    try {
      _connection = flutterReactiveBle
          .connectToDevice(
        id: device.id,
        connectionTimeout: const Duration(seconds: 6),
      )
          .listen((connectionState) {
        if (connectionState.connectionState ==
            DeviceConnectionState.connected) {
          setState(() {
            _connectedDevice = device;
            _isConnected = true;
            _Characteristic = QualifiedCharacteristic(
              serviceId: Uuid.parse(serviceUuid),
              characteristicId: Uuid.parse(txUuid),
              deviceId: _connectedDevice.id,
            );
            toastFun('Connected to ${device.name}', true);
          });
        } else if (connectionState.connectionState ==
            DeviceConnectionState.disconnected) {}
      });
    } catch (e) {
      print("Error while connecting: $e");
    }
  }

  /*
  Title: BLE Scan
  Description: This function scans the surrounding BLE devices
 */
  void startScan() {
    setState(() {
      isScanning = true;
      _foundDevices.clear(); // Clear previous devices
    });

    // Start scanning for BLE devices
    _scanStream =
        flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
      // Add devices to the discovered list if not already present
      setState(() {
        if (!_foundDevices.any((d) => d.id == device.id)) {
          if (SavedDeviceID == device.id) {
            _scanStream.cancel(); /* Stops Scanning */
            _connectToDevice(device);
          }
        }
      });
    }, onError: (e) {
      _scanStream.cancel(); /* Stops Scanning */
      isScanning = false;
    });
  }

  @override
  void initState() {
    super.initState();
    batteryLevel = 0;
    BatteryAnimation();
    initPackage();
  }

  @override
  void dispose() {
    _controller.dispose(); // Dispose the animation controller when not in use
    batteryLevel = 0;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.grey[900], // Background color
        body: Center(
          child: Column(
            children: [
              Expanded(
                flex: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    !isGlobalVariableTrue
                        ? Column(
                            children: [
                              const Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Always Be',
                                      style: TextStyle(
                                          fontSize: 40.0,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    DefaultTextStyle(
                                      style: const TextStyle(
                                        fontSize: 25.0,
                                        fontFamily: 'Horizon',
                                      ),
                                      child: AnimatedTextKit(
                                        /* Don't repeat the animation */
                                        repeatForever: false,
                                        totalRepeatCount: 1,
                                        isRepeatingAnimation: false,
                                        animatedTexts: [
                                          RotateAnimatedText(
                                            'CHARGED',
                                            duration: const Duration(
                                                milliseconds:
                                                    800), // Duration per word
                                          ),
                                          RotateAnimatedText(
                                            'POWERED',
                                            duration: const Duration(
                                                milliseconds:
                                                    800), // Duration per word
                                          ),
                                          RotateAnimatedText(
                                            'READY',
                                            duration: const Duration(
                                                milliseconds:
                                                    800), // Duration per word
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: AnimatedTextKit(
                                  animatedTexts: [
                                    ColorizeAnimatedText(
                                      'SMART HUB',
                                      textStyle: colorizeTextStyle,
                                      speed: const Duration(milliseconds: 1000),
                                      colors: colorizeColors,
                                    ),
                                  ],
                                  isRepeatingAnimation: true,
                                ),
                              ),
                            ],
                          ),
                    const SizedBox(width: 20),
                    Container(
                      width: 3,
                      height: 200,
                      color: Colors.white,
                    ),
                    const SizedBox(
                      width: 20,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 60,
                          height: 120, // Increase height for a vertical battery
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: Stack(
                            children: [
                              // Empty battery background
                              Positioned.fill(
                                child: Container(
                                  color: Colors.transparent,
                                ),
                              ),

                              // Filling part (battery charging) - Now Vertical
                              Positioned.fill(
                                child: FractionallySizedBox(
                                  heightFactor:
                                      batteryLevel, // Change to heightFactor for vertical filling
                                  alignment: Alignment
                                      .bottomCenter, // Fill from bottom to top
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: getBatteryColor(
                                          batteryLevel), // Dynamic color based on battery level
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(8),
                                        bottomRight: Radius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Battery percentage display
                        Text(
                          '${(batteryLevel * 100).toInt()}%',
                          style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                  child: Column(
                children: [
                  Text(
                    'SmartHUB App powered by EOIP\n $version',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white60, fontWeight: FontWeight.w500),
                  ),
                ],
              ))
            ],
          ),
        ),
      ),
    );
  }
}
