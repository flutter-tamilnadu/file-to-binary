import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class AboutWidget extends StatelessWidget {
  const AboutWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        web.window.location.href = '/about.html';
      },
      child: Icon(Icons.account_circle_rounded,
          color: Colors.blueAccent,
          size: 40),
    );
  }
}
