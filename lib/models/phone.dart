/// Par où le téléphone est relié au PC.
enum LinkKind { usb, wifi }

/// État d'une liaison, tel que le service adb le rapporte.
enum LinkState {
  /// Utilisable : l'écran peut être affiché.
  ready,

  /// Le téléphone attend que l'utilisateur accepte la fenêtre « Autoriser le débogage ».
  unauthorized,

  /// Liaison en cours d'établissement.
  connecting,

  /// Vu par le PC mais inutilisable (téléphone verrouillé au démarrage, liaison perdue…).
  offline,
}

/// Une liaison adb : un même téléphone en a deux s'il est à la fois branché et en Wi-Fi.
class AdbDevice {
  const AdbDevice({required this.serial, required this.state, this.rawState = '', this.model = ''});

  /// Identifiant de la liaison : numéro de série en USB, `adresse:port` en Wi-Fi.
  final String serial;
  final LinkState state;

  /// État brut renvoyé par adb, pour le diagnostic.
  final String rawState;

  /// Modèle annoncé par le téléphone (ex. `SM-S931B`), vide tant qu'il n'est pas autorisé.
  final String model;

  LinkKind get kind => isNetworkSerial(serial) ? LinkKind.wifi : LinkKind.usb;

  bool get ready => state == LinkState.ready;

  @override
  bool operator ==(Object other) =>
      other is AdbDevice && other.serial == serial && other.state == state && other.model == model;

  @override
  int get hashCode => Object.hash(serial, state, model);

  @override
  String toString() => 'AdbDevice($serial, ${state.name})';
}

final _addressSerial = RegExp(r'^(\[[0-9a-fA-F:]+\]|[^\s:]+):\d{1,5}$');

/// Vrai pour une liaison réseau : `192.168.1.20:5555`, ou le nom de service annoncé par
/// le débogage sans fil (`adb-R5XXXXXXXXX-AbCdEf._adb-tls-connect._tcp`).
bool isNetworkSerial(String serial) => serial.contains('._adb-tls-connect.') || _addressSerial.hasMatch(serial);

/// Un téléphone, avec toutes ses liaisons.
class Phone {
  const Phone({required this.id, required this.name, required this.links});

  /// Numéro de série matériel quand il est connu, sinon l'identifiant de la liaison.
  final String id;

  /// Nom affiché : celui choisi sur le téléphone (« Galaxy S25 »), à défaut le modèle.
  final String name;
  final List<AdbDevice> links;

  /// Liaison à utiliser pour afficher l'écran : le câble d'abord (plus rapide et plus
  /// stable), le Wi-Fi sinon. `null` si aucune liaison n'est prête.
  AdbDevice? get bestLink => linkOf(LinkKind.usb, readyOnly: true) ?? linkOf(LinkKind.wifi, readyOnly: true);

  AdbDevice? linkOf(LinkKind kind, {bool readyOnly = false}) {
    for (final link in links) {
      if (link.kind == kind && (!readyOnly || link.ready)) return link;
    }
    return null;
  }

  bool get ready => bestLink != null;

  bool get hasUsb => linkOf(LinkKind.usb, readyOnly: true) != null;

  bool get hasWifi => linkOf(LinkKind.wifi, readyOnly: true) != null;

  /// Aucune liaison prête, et au moins une en attente d'autorisation sur le téléphone.
  bool get needsAuthorization => !ready && links.any((l) => l.state == LinkState.unauthorized);
}

/// Un téléphone déjà relié en Wi-Fi, mémorisé pour s'y reconnecter d'un clic.
class WifiAddress {
  const WifiAddress({required this.address, this.name = '', this.id = ''});

  /// `adresse:port`, ex. `192.168.1.20:5555`.
  final String address;
  final String name;

  /// Numéro de série matériel du téléphone, s'il était connu au moment de l'enregistrement.
  final String id;

  Map<String, dynamic> toJson() => {'address': address, 'name': name, 'id': id};

  factory WifiAddress.fromJson(Map<String, dynamic> json) => WifiAddress(
    address: json['address'] as String? ?? '',
    name: json['name'] as String? ?? '',
    id: json['id'] as String? ?? '',
  );
}

/// Un téléphone qui s'annonce sur le réseau local (débogage sans fil d'Android 11+).
class NearbyService {
  const NearbyService({required this.name, required this.address, required this.pairing});

  /// Nom annoncé, ex. `adb-R5XXXXXXXXX-AbCdEf`.
  final String name;

  /// `adresse:port`.
  final String address;

  /// Vrai pour le service d'association (code à six chiffres), faux pour le service
  /// de connexion.
  final bool pairing;

  String get host => address.substring(0, address.lastIndexOf(':'));
}
