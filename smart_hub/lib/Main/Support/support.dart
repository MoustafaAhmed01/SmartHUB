import 'package:flutter/material.dart';

/// TODO: Build the support screen
///
class support_screen extends StatelessWidget {
  static String id = 'Support_Screen';
  const support_screen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Support'),
        ),
        body: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Text(
                'Support Screen',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
