import 'package:web/web.dart' as web;

bool get prefereReduzirMovimento =>
    web.window.matchMedia('(prefers-reduced-motion: reduce)').matches;
