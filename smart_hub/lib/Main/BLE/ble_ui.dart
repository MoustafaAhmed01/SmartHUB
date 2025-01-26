import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_hub/Components/alerts.dart';
import 'package:smart_hub/Main/Support/support.dart';
import 'package:smart_hub/Main/home/home_screen.dart';

import '../../Components/ble_alerts.dart';
import '../../Constants/ble_constants.dart'; // For Timer functionality

/// -----------------Global Variables-------------------------*

/// -----------------------------------------------------------*
class ble_ui_screen extends StatefulWidget {
  static String id = 'BLE_screen';

  const ble_ui_screen({super.key});

  @override
  State<ble_ui_screen> createState() => _ble_ui_screenState();
}

class _ble_ui_screenState extends State<ble_ui_screen>
    with SingleTickerProviderStateMixin {
  /// ---------------------Local Variables Section----------------------*
  /* Variables used to run the BLE is required.
  * These variables used to init the BLE, scan the surrounding devices, and
  * saving the characteristics of the connected device */
  final flutterReactiveBle = FlutterReactiveBle();
  late StreamSubscription<DiscoveredDevice> _scanStream;
  late Stream<BleStatus> _bleStatusStream;
  final List<DiscoveredDevice> _foundDevices = [];
  late QualifiedCharacteristic _Characteristic;
  late DiscoveredDevice _connectedDevice;
  late StreamSubscription<ConnectionStateUpdate> _connection;

  bool isScanning =
      false; /* If the used pressed on the BLE icon this variable will be true otherwise it will be false.
       It's just required to know if the app is currently scanning for a new devices or not */
  bool isPairing =
      false; /* This variable saves the state of the BLE. If it's connected to a device then it will be true
    if not it will false */
  bool isNavigated = false; /*  */

  Timer?
      _scanTimer; /* Timer to strict the scanning process to be limited with a certain time */
  Map<String, bool> isLoadingMap = {};
  Map<String, bool> isPairedMap = {};

  bool devicePaired = false;
  String? pairedDeviceName;
  String? pairedDeviceId;
  late String SavedDeviceID;

  /* Local storage  */
  late final SharedPreferences prefs;

  final Map<String, StreamSubscription<ConnectionStateUpdate>> _subscriptions =
      {};
  Map<String, bool> connectedDevices =
      {}; // Track connection state by device ID

  // Animation controller for button feedback
  late AnimationController _controller;
  late Animation<double> _animation;

  /**------------------------------------------------------------------**/

  /// ------------------------Function Section--------------------------*
  void ble_enable_state_check() {
    _bleStatusStream.listen((status) {
      if (status == BleStatus.ready) {
        print('Bluetooth is ON');
      } else if (status == BleStatus.poweredOff) {
        print('Bluetooth is OFF');
        errorCheckble(context, 'BLE_OFF');

        /// TODO: save the state of the bluetooth state in a variable because when the user presses ok in case he got the pop message that his bluetooth is turned off. The pop message will just disappear. So, we need to handle it by saving the state of the BLE and then turning off the control from the BLE Icon make it non-responsive till the user turn it back on.
      } else {
        print('Bluetooth status: $status');
      }
    });
  }

  // Function to start BLE scanning
  void startScan() {
    setState(() {
      isScanning = true;
      _foundDevices.clear(); // Clear previous devices
      _controller.forward(); // Start the heartbeat animation
    });

    // Start scanning for BLE devices
    _scanStream =
        flutterReactiveBle.scanForDevices(withServices: []).listen((device) {
      // Add devices to the discovered list if not already present
      setState(() {
        if (!_foundDevices.any((d) => d.id == device.id)) {
          if (device.name != '') {
            _foundDevices.add(device);
          }
        }
      });
    }, onError: (e) {
      print("Error scanning for devices: $e");
      stopScan();
      isScanning = false;
    });

    // Set a timer to stop the scan after 10 seconds
    _scanTimer = Timer(const Duration(seconds: 10), () {
      stopScan();
    });
  }

  // Function to stop BLE scanning
  void stopScan() {
    setState(() {
      isScanning = false;
      _controller.stop(); // Stop heartbeat animation
      _scanStream.cancel(); /* Stops Scanning */
    });
    // Cancel the timer if it's still running
    _scanTimer?.cancel();
  }

  // Function to handle stop button press
  void onStopButtonPressed() {
    stopScan(); // Manually stop scanning
  }

  // Function to handle scan button press
  void onScanButtonPressed() {
    if (!isScanning) {
      startScan(); // Start scanning for devices
    }
  }

  Future<void> disconnectDevice(String deviceId) async {
    await _connection.cancel();
    toastFun('Unpaired', true);
    setState(() {
      isPairedMap[deviceId] = false;
    });
  }

  Future<void> saveToLocalStorage(DiscoveredDevice device) async {
    await prefs.setString('ConnectedDevice', device.id); // save the device id
  }

  // Connect to a device
  Future<void> _connectToDevice(DiscoveredDevice device) async {
    setState(() {
      isLoadingMap[device.id] = true;
      isPairedMap[device.id] = false;
      isNavigated = false;
    });

    try {
      _connection = flutterReactiveBle
          .connectToDevice(
        id: device.id,
        connectionTimeout: const Duration(seconds: 5),
      )
          .listen((connectionState) {
        if (connectionState.connectionState ==
            DeviceConnectionState.connected) {
          setState(() {
            isNavigated = true;
            isPairing = false;
            // Discover services and characteristics
            _Characteristic = QualifiedCharacteristic(
              serviceId: Uuid.parse(serviceUuid),
              characteristicId: Uuid.parse(txUuid),
              deviceId: device.id,
            );

            /// TODO: We need to make sure that the device is connected to smart hub because like that if the device is connected to any bluetooth device it will take you to the home screen. So, we need to make sure that the user is pairing with a correct device. We can do this by 1- making sure the device name is SmartHUB  2- exchanging some info before navigating like receiving a specific pattern to make sure that's it  ///
            _connectedDevice = device;
            toastFun('Connected to ${device.name}', true);
            isLoadingMap[device.id] = false;
            isPairedMap[device.id] = true;
            saveToLocalStorage(device);
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
          });
        } else if (connectionState.connectionState ==
            DeviceConnectionState.disconnected) {
          setState(() {
            isPairing = false;
            isLoadingMap[device.id] = false;
            isPairedMap[device.id] = false;
            if (isNavigated == false) toastFun('Not Connected', true);
          });
        }
      });
    } catch (e) {
      print("Error while connecting: $e");
      setState(() {
        isPairing = false;
        isLoadingMap[device.id] = false;
        isPairedMap[device.id] = false;
      });
      toastFun('Error while Connecting', true);
    }
  }

  // Function to get device services
  Future<List<String>> getDeviceServices(String deviceId) async {
    try {
      // Connect to the device to discover services
      await flutterReactiveBle.connectToDevice(id: deviceId).first;
      final services = await flutterReactiveBle.discoverServices(deviceId);

      // Extract UUID strings from the services
      return services.map((service) => service.serviceId.toString()).toList();
    } catch (e) {
      print('Failed to discover services for $deviceId: $e');
      return [];
    }
  }

  // Function to map Device name to an icon
  IconData getServiceIcon(String DeviceName) {
    if (RegExp(r"SmartHUB").hasMatch(DeviceName)) {
      return Icons.battery_charging_full;
    } else if (RegExp(r"[TV]").hasMatch(DeviceName)) {
      return Icons.connected_tv_rounded;
    } else if (RegExp(r"TV").hasMatch(DeviceName)) {
      return Icons.connected_tv_rounded;
    } else if (RegExp(r"Band").hasMatch(DeviceName)) {
      return Icons.watch;
    } else if (RegExp(r"Watch").hasMatch(DeviceName)) {
      return Icons.watch;
    } else if (RegExp(r"keyboard").hasMatch(DeviceName)) {
      return Icons.keyboard_alt_outlined;
    } else if (RegExp(r"mouse").hasMatch(DeviceName)) {
      return Icons.mouse;
    } else if (RegExp(r"speaker").hasMatch(DeviceName)) {
      return Icons.speaker;
    } else if (RegExp(r"printer").hasMatch(DeviceName)) {
      return Icons.print;
    } else {
      return Icons.bluetooth;
    }
  }

  Future<void> initPackages() async {
    _bleStatusStream = flutterReactiveBle.statusStream;
    prefs = await SharedPreferences.getInstance();
  }

  /// ------------------------------------------------------------------*
  @override
  void initState() {
    super.initState();
    initPackages();
    ble_enable_state_check();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 600), // Adjust for heartbeat speed
      vsync: this,
    )..addListener(() {
        setState(() {});
      });

    // Tween for heartbeat scaling effect
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanTimer?.cancel();
    _scanStream.cancel();
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900], // Background color
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Header
            const Text(
              'Identifying Charger',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            const Text(
              'Find the closest SmartHUB charger \nvia bluetooth',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 15,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 40),
            // Bluetooth Button with Heartbeat Animation
            GestureDetector(
              onTap: onScanButtonPressed,
              child: Transform.scale(
                scale: isScanning
                    ? _animation.value
                    : 1.0, // Apply the scaling animation
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Colors.blueAccent, Colors.transparent],
                      stops: [0.5, 1.0],
                      center: Alignment.center,
                      radius: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.5),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    isScanning ? Icons.bluetooth_searching : Icons.bluetooth,
                    size: 80,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            // Stop Button
            if (isScanning)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Found your device ? ',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(
                    width: 5,
                  ),
                  ElevatedButton(
                    onPressed: onStopButtonPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, // Button color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'Stop Scan',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            // Scanned Devices (cards)
            const SizedBox(
              height: 10,
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _foundDevices.length,
                itemBuilder: (context, index) {
                  final device = _foundDevices[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white54, width: 1),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.05),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              // Service Icon
                              Icon(
                                getServiceIcon(device.name),
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(width: 15),
                              // Device Name and Service Name
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      device.name.isNotEmpty
                                          ? device.name
                                          : "Unknown device",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    ("ID: ${device.id}\nRSSI: ${device.rssi} dBm"),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          isPairedMap[device.id] == true
                              ? ElevatedButton(
                                  onPressed: () {
                                    // Pairing logic here
                                    if (!isScanning) {
                                      disconnectDevice(device.id);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red, // Button color
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  child: const Text(
                                    'unPair',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : isLoadingMap[device.id] == true
                                  ? Container(
                                      width: 77,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: Colors.blueAccent,
                                        borderRadius: BorderRadius.all(
                                            Radius.circular(20)),
                                      ),
                                      child:
                                          LoadingAnimationWidget.dotsTriangle(
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    )
                                  : ElevatedButton(
                                      onPressed: () {
                                        // Pairing logic here
                                        if (!isScanning) {
                                          if (isPairing == false) {
                                            setState(() {
                                              isPairing = true;
                                            });
                                            _connectToDevice(device);
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            Colors.blueAccent, // Button color
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text(
                                        'Pair',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                bottom: 10,
                right: 40,
                left: 40,
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: Colors.white30,
                    child: const Text(''),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Need help ?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(
                        width: 1,
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pushReplacementNamed(
                              context, support_screen.id);
                        },
                        child: const Text(
                          'Support',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
