import '../../models/phone.dart';

/// Lit la réponse de `host:devices-l` : une liaison par ligne.
///
/// ```
/// R5XXXXXXXXX            device usb:1-2 product:pa1qxxx model:SM_S931B device:pa1q transport_id:3
/// 192.168.1.20:5555      device product:pa1qxxx model:SM_S931B device:pa1q transport_id:4
/// R5XXXXXXXXX            unauthorized usb:1-2 transport_id:5
/// ```
List<AdbDevice> parseDevices(String text) {
  final devices = <AdbDevice>[];
  for (final line in text.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || parts.first.isEmpty) continue;
    var model = '';
    for (final part in parts.skip(2)) {
      if (part.startsWith('model:')) model = part.substring(6).replaceAll('_', '-');
    }
    devices.add(
      AdbDevice(
        serial: parts[0],
        rawState: parts[1],
        state: switch (parts[1]) {
          'device' => LinkState.ready,
          'unauthorized' => LinkState.unauthorized,
          'connecting' || 'authorizing' => LinkState.connecting,
          _ => LinkState.offline,
        },
        model: model,
      ),
    );
  }
  return devices;
}

/// Lit la réponse de `host:mdns:services` : les téléphones qui s'annoncent sur le réseau.
///
/// ```
/// adb-R5XXXXXXXXX-AbCdEf	_adb-tls-connect._tcp	192.168.1.20:37251
/// adb-R5XXXXXXXXX-AbCdEf	_adb-tls-pairing._tcp	192.168.1.20:41873
/// ```
List<NearbyService> parseMdnsServices(String text) {
  final services = <NearbyService>[];
  for (final line in text.split('\n')) {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.length < 3) continue;
    final type = parts[1];
    final address = parts[2];
    if (!RegExp(r':\d{1,5}$').hasMatch(address)) continue;
    if (type.startsWith('_adb-tls-pairing')) {
      services.add(NearbyService(name: parts[0], address: address, pairing: true));
    } else if (type.startsWith('_adb-tls-connect')) {
      services.add(NearbyService(name: parts[0], address: address, pairing: false));
    }
  }
  return services;
}

final _mdnsName = RegExp(r'^adb-([A-Za-z0-9]+)-[A-Za-z0-9]+');

/// Numéro de série matériel contenu dans un nom de service du débogage sans fil
/// (`adb-R5XXXXXXXXX-AbCdEf…` → `R5XXXXXXXXX`), ou `null`.
String? hardwareSerialFromMdnsName(String name) => _mdnsName.firstMatch(name)?.group(1);

final _routeSource = RegExp(r'\bdev\s+(\S+).*\bsrc\s+(\d{1,3}(?:\.\d{1,3}){3})');
final _inetAddress = RegExp(r'\binet\s+(\d{1,3}(?:\.\d{1,3}){3})/');

/// Adresse du téléphone sur le Wi-Fi, lue dans la sortie de `ip route` ou de
/// `ip -f inet addr show wlan0`. `null` si le téléphone n'est pas sur un réseau Wi-Fi.
String? parseWifiIp(String text) {
  String? fallback;
  for (final line in text.split('\n')) {
    final route = _routeSource.firstMatch(line);
    if (route != null) {
      // Seule l'interface Wi-Fi convient : le réseau mobile (rmnet) n'est pas joignable du PC.
      if (route.group(1)!.startsWith('wlan')) return route.group(2);
      continue;
    }
    fallback ??= _inetAddress.firstMatch(line)?.group(1);
  }
  return fallback;
}

final _hostName = RegExp(r'^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$');

/// Met une adresse saisie sous la forme `hôte:port` (port 5555 par défaut).
/// Renvoie `null` si la saisie n'est pas une adresse.
String? normalizeAddress(String input, {int defaultPort = 5555}) {
  final text = input.trim();
  if (text.isEmpty) return null;
  var host = text;
  var port = defaultPort;
  final colon = text.lastIndexOf(':');
  if (colon > 0) {
    final parsed = int.tryParse(text.substring(colon + 1));
    if (parsed == null) return null;
    host = text.substring(0, colon);
    port = parsed;
  }
  if (port < 1 || port > 65535 || !_hostName.hasMatch(host)) return null;
  return '$host:$port';
}

/// Résultat d'une demande de connexion ou d'association.
class AdbOutcome {
  const AdbOutcome(this.ok, this.message);

  final bool ok;

  /// Message à afficher, en français.
  final String message;
}

/// Interprète la réponse de `host:connect:…` (adb répond `OKAY` même en cas d'échec).
AdbOutcome parseConnectReply(String reply, String address) {
  final text = reply.trim();
  if (text.startsWith('connected to') || text.startsWith('already connected')) {
    return AdbOutcome(true, 'Connecté à $address.');
  }
  final lower = text.toLowerCase();
  if (lower.contains('refused') || lower.contains('10061')) {
    return AdbOutcome(
      false,
      'Le téléphone à l\'adresse $address refuse la connexion : le débogage par Wi-Fi n\'y est pas activé '
      '(il se désactive à chaque redémarrage du téléphone).',
    );
  }
  if (lower.contains('timed out') ||
      lower.contains('10060') ||
      lower.contains('no route') ||
      lower.contains('unreachable')) {
    return AdbOutcome(
      false,
      'Aucune réponse de $address. Vérifiez que le téléphone est allumé et sur le même réseau Wi-Fi que le PC.',
    );
  }
  return AdbOutcome(false, 'Connexion à $address impossible : $text');
}

/// Interprète la réponse de `host:pair:…`.
AdbOutcome parsePairReply(String reply) {
  final text = reply.trim();
  if (text.startsWith('Successfully paired')) {
    return const AdbOutcome(true, 'Téléphone associé.');
  }
  if (text.toLowerCase().contains('wrong password')) {
    return const AdbOutcome(
      false,
      'Code refusé. Vérifiez le code à six chiffres et l\'adresse affichés sur le téléphone.',
    );
  }
  return AdbOutcome(false, 'Association impossible : $text');
}
