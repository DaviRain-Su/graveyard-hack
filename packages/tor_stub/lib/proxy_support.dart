enum ProxyType { socks5, http }

class ProxyInfo {
  final String address;
  final int port;
  final ProxyType type;

  ProxyInfo({required this.address, required this.port, required this.type});
}
