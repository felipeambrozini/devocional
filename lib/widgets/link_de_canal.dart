import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DevocionalLinkDeCanal extends StatelessWidget {
  const DevocionalLinkDeCanal({
    super.key,
    required this.asset,
    required this.rotulo,
    required this.url,
  });

  final String asset;
  final String rotulo;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Image.asset(
        asset,
        // O logo oficial da marca, como o "G" do Google: não redesenhado.
        width: 26,
        height: 26,
      ),
      title: Text(rotulo),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
