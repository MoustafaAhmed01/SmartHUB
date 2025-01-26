import 'package:flutter/material.dart';

import '../Constants/battery_constants.dart';

/*
  Description:
  - This class handles the battery shape of the power bank.
  - You should pass some variables at first such as:
   * Battery Level
   * is the power bank connected to the charger or not
   * Constant
   * The current theme which is already saved by a provider

 */
class BatteryIndicator extends StatelessWidget {
  final double batteryLevel; // A value between 0 and 1
  final bool isCharging;
  final double circleRadius;
  final bool isDark;

  const BatteryIndicator({
    super.key,
    required this.batteryLevel,
    required this.isCharging,
    required this.circleRadius,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Color batteryColor;
    Color chargingColor;
    if (batteryLevel > 0.75) {
      batteryColor = Colors.green;
      chargingColor = Colors.white;
    } else if (batteryLevel <= 0.75 && batteryLevel > 0.3) {
      batteryColor = Colors.yellow;
      chargingColor = Colors.green;
    } else if (batteryLevel <= 0.3 && batteryLevel >= 0) {
      batteryColor = Colors.red;
      chargingColor = Colors.green;
    } else {
      batteryColor = Colors.red;
      chargingColor = Colors.green;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.all(
          Radius.circular(
            20,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(
            height: 10,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                /* Stack is used to draw the levels of the battery */
                children: [
                  // Outer battery container (battery outline)
                  Container(
                    width: 45,
                    height: 20,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white38, width: 2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  // Battery tip (small rectangular shape for the tip of the battery)

                  // Filled portion of the battery representing the current battery level
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 2.6,
                      left: 2,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: Container(
                        width: 45 *
                            batteryLevel, // Width based on battery percentage
                        height: 15,
                        color:
                            batteryColor, // Color changes based on battery level
                      ),
                    ),
                  ),
                  isCharging
                      ? Positioned(
                          left: 16,
                          top: 2,
                          child: Icon(
                            Icons.flash_on,
                            color: chargingColor,
                            size: 18,
                          ),
                        )
                      : Container(),
                ],
              ),
              Container(
                width: 4,
                height: 7,
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(
                      edgeRadius,
                    ),
                    bottomRight: Radius.circular(
                      edgeRadius,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            '${(batteryLevel * 100).toInt()}%',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
