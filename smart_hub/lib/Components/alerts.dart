import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

/*
 Description: This function used to to display an error message on the screen
 Just by receiving the context of the screen where you are and some sort of data
 and the alert type

 You should call it by using the errorCheck function
 */
void alertFun(
    BuildContext context, String title, String descrip, AlertType alertType) {
  Alert(
    context: context,
    type: alertType,
    title: title,
    desc: descrip,
    style: const AlertStyle(
      backgroundColor: Color(0x9929283A),
      alertElevation: 30,
      animationType: AnimationType.grow,
      alertBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(30),
        ),
      ),
      titleStyle: TextStyle(
        color: Colors.white, // Set the title color here
        fontSize: 24, // Adjust the font size if necessary
        fontWeight: FontWeight.bold,
      ),
      descStyle: TextStyle(
        color: Colors.white70, // Set the description text color here
        fontSize: 16,
      ),
    ),
    buttons: [
      DialogButton(
        color: Colors.white12,
        onPressed: () => Navigator.pop(context),
        radius: BorderRadius.circular(20),
        width: 120,
        child: const Text(
          "Ok",
          style: TextStyle(color: Color(0xFFd5d1dd), fontSize: 20),
        ),
      )
    ],
  ).show();
}

/*
Description: This function receives the context of the current UI screen and the
error message.
You have to setup your own command, message and the Alert type.
 */
void errorCheck(BuildContext context, String errorMessage) {
  if (errorMessage == 'BLE') {
    alertFun(
        context,
        'Permission Error',
        'Please enable the access for location and bluetooth and then try again!',
        AlertType.warning);
  } else if (errorMessage == 'BLE_OFF') {
    alertFun(context, 'Bluetooth issue', 'Please turn on your bluetooth!',
        AlertType.warning);
  } else {
    alertFun(
      context,
      'Error',
      'Unknown error!\n try again',
      AlertType.error,
    );
  }
}

void toastFun(String title, bool isDark) {
  Fluttertoast.cancel();
  Fluttertoast.showToast(
    msg: title,
    gravity: ToastGravity.BOTTOM,
    backgroundColor: isDark ? Colors.white24 : Colors.black87,
    textColor: Colors.white,
    fontSize: 16.0,
  );
}
