import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../models.dart';

class TabView extends StatelessWidget {
  final EmailTab tab;

  const TabView({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: tab.isHtml
            ? Html(data: tab.content)
            : SelectableText(
                tab.content,
                style: const TextStyle(fontSize: 16),
              ),
      ),
    );
  }
}
