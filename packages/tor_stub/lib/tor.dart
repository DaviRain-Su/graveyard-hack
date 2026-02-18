import 'proxy_support.dart';

class Tor {
  static final Tor instance = Tor._();
  Tor._();

  bool started = false;
  bool bootstrapped = false;
  int port = 0;

  static Future<void> init({bool enabled = false}) async {}

  Future<void> start() async {}
  Future<void> stop() async {}

  void updateCustomProxy(ProxyInfo? proxy) {}

  ProxyInfo? currentSystemProxy() => null;
}
