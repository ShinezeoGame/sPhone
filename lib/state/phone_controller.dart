import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/adb/adb_client.dart';
import '../data/adb/adb_parsers.dart';
import '../data/adb/adb_server.dart';
import '../data/app_window.dart';
import '../data/scrcpy.dart';
import '../data/settings.dart';
import '../data/tools.dart';
import '../models/phone.dart';

/// État de la liaison avec le service adb.
enum ServiceState { starting, ready, failed }

/// Message affiché en haut de l'écran après une action.
class Notice {
  const Notice(this.message, {this.error = false});

  final String message;
  final bool error;
}

/// Un affichage en cours : la fenêtre scrcpy d'un téléphone.
class MirrorSession {
  MirrorSession({required this.phoneId, required this.phoneName, required this.serial, required this.kind});

  final String phoneId;
  final String phoneName;

  /// Liaison utilisée.
  final String serial;
  final LinkKind kind;

  Process? _process;
  bool _stoppedByUser = false;
  bool _minimized = false;
  final DateTime _startedAt = DateTime.now();

  /// Dernières lignes écrites par scrcpy, pour expliquer un échec.
  final List<String> _log = [];
}

class _Identity {
  const _Identity(this.hardwareId, this.name);

  final String hardwareId;
  final String name;
}

/// État de l'application : téléphones visibles, affichage en cours, connexions Wi-Fi.
class PhoneController extends ChangeNotifier {
  PhoneController({
    AdbClient? client,
    Tools? tools,
    AdbServer? server,
    SettingsStore? store,
    AppWindow? window,
    this.launcher = Process.start,
    Directory Function()? screenshotDirectory,
    this.retryDelay = const Duration(seconds: 2),
    this.wifiRetryDelay = const Duration(milliseconds: 800),
    this.minimizeDelay = const Duration(milliseconds: 1500),
  }) : client = client ?? AdbClient(),
       tools = tools ?? Tools.locate(),
       _store = store ?? SettingsStore(),
       window = window ?? const NoWindow(),
       _screenshotDirectory = screenshotDirectory ?? defaultScreenshotDirectory {
    this.server = server ?? AdbServer(client: this.client, adbPath: this.tools.adb);
  }

  final AdbClient client;
  final Tools tools;
  late final AdbServer server;
  final AppWindow window;
  final SettingsStore _store;
  final ProcessLauncher launcher;
  final Directory Function() _screenshotDirectory;

  /// Délai avant de retenter de joindre le service adb.
  final Duration retryDelay;

  /// Délai entre deux essais de connexion après le passage en Wi-Fi.
  final Duration wifiRetryDelay;

  /// Délai avant de réduire sPhone une fois l'affichage lancé (le temps que la fenêtre
  /// du téléphone apparaisse, ou qu'un échec de démarrage se déclare).
  final Duration minimizeDelay;

  Settings _settings = const Settings();
  Settings get settings => _settings;

  ServiceState _service = ServiceState.starting;
  ServiceState get service => _service;

  String? _serviceError;
  String? get serviceError => _serviceError;

  List<Phone> _phones = const [];
  List<Phone> get phones => _phones;

  MirrorSession? _session;
  MirrorSession? get session => _session;

  Notice? _notice;
  Notice? get notice => _notice;

  List<NearbyService> _nearby = const [];

  /// Téléphones qui s'annoncent sur le réseau (débogage sans fil).
  List<NearbyService> get nearby => _nearby;

  final Set<String> _busy = {};

  /// Vrai pendant qu'une action longue est en cours (`wifi:<id>`, `connect`, `pair`, `shot:<id>`).
  bool isBusy(String key) => _busy.contains(key);

  List<AdbDevice> _devices = const [];
  final Map<String, _Identity> _identities = {};
  final Set<String> _identifying = {};

  /// Téléphones dont l'utilisateur a fermé l'affichage : ils ne sont pas réaffichés
  /// automatiquement tant qu'ils restent connectés.
  final Set<String> _dismissed = {};

  StreamSubscription<String>? _tracking;
  bool _started = false;
  bool _disposed = false;

  // ── Démarrage et arrêt ──

  Future<void> loadSettings() async {
    _settings = await _store.load();
    notifyListeners();
  }

  /// Démarre le service adb et suit en continu les téléphones connectés.
  void start() {
    if (_started) return;
    _started = true;
    unawaited(_serviceLoop());
  }

  Future<void> _serviceLoop() async {
    while (!_disposed) {
      try {
        await server.ensureRunning();
        if (_disposed) return;
        _setService(ServiceState.ready);
        unawaited(_reconnectSaved());
        final lost = Completer<void>();
        void finish() {
          if (!lost.isCompleted) lost.complete();
        }

        _tracking = client
            .track('host:track-devices-l')
            .listen(
              (text) => applyDevices(parseDevices(text)),
              onError: (Object _) => finish(),
              onDone: finish,
              cancelOnError: true,
            );
        await lost.future;
        if (_disposed) return;
        // Service arrêté (par un autre outil, par exemple) : on repart de zéro.
        applyDevices(const []);
        _setService(ServiceState.starting);
      } on Object catch (error) {
        if (_disposed) return;
        _setService(ServiceState.failed, error is AdbException ? error.message : error.toString());
      }
      await Future<void>.delayed(retryDelay);
    }
  }

  void _setService(ServiceState state, [String? error]) {
    if (_service == state && _serviceError == error) return;
    _service = state;
    _serviceError = error;
    notifyListeners();
  }

  /// Arrête l'affichage et le service adb : appelé à la fermeture de l'application.
  Future<void> shutdown() async {
    if (_disposed) return;
    _disposed = true;
    await _tracking?.cancel();
    final session = _session;
    if (session != null) {
      session._stoppedByUser = true;
      session._process?.kill();
    }
    await server.stopIfOwned();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_tracking?.cancel());
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ── Téléphones ──

  /// Met à jour la liste des liaisons vues par adb.
  @visibleForTesting
  void applyDevices(List<AdbDevice> devices) {
    _devices = devices;
    final serials = {for (final d in devices) d.serial};
    _identities.removeWhere((serial, _) => !serials.contains(serial));
    for (final device in devices) {
      if (device.ready && !_identities.containsKey(device.serial) && !_identifying.contains(device.serial)) {
        unawaited(_identify(device.serial));
      }
    }
    _rebuild();
  }

  /// Demande au téléphone son numéro de série et le nom que l'utilisateur lui a donné :
  /// le premier permet de réunir ses liaisons USB et Wi-Fi, le second de le nommer.
  Future<void> _identify(String serial) async {
    _identifying.add(serial);
    var hardwareId = '';
    var name = '';
    try {
      final lines = const LineSplitter().convert(
        await client.shell(serial, 'getprop ro.serialno; settings get global device_name'),
      );
      if (lines.isNotEmpty) hardwareId = lines[0].trim();
      if (lines.length > 1 && lines[1].trim() != 'null') name = lines[1].trim();
    } on Object {
      // Sans réponse, le téléphone garde le nom de son modèle.
    }
    _identifying.remove(serial);
    if (_disposed || !_devices.any((d) => d.serial == serial && d.ready)) return;
    _identities[serial] = _Identity(hardwareId, name);
    _rebuild();
  }

  /// Identité connue d'une liaison, sans passer par adb (tests et aperçus).
  @visibleForTesting
  void setIdentity(String serial, {String hardwareId = '', String name = ''}) {
    _identities[serial] = _Identity(hardwareId, name);
    _rebuild();
  }

  String _phoneIdOf(AdbDevice device) {
    final known = _identities[device.serial]?.hardwareId ?? '';
    if (known.isNotEmpty) return known;
    final fromName = hardwareSerialFromMdnsName(device.serial);
    if (fromName != null) return fromName;
    // Adresse Wi-Fi mémorisée : on sait déjà de quel téléphone il s'agit.
    for (final saved in _settings.wifi) {
      if (saved.address == device.serial && saved.id.isNotEmpty) return saved.id;
    }
    return device.serial;
  }

  void _rebuild() {
    final groups = <String, List<AdbDevice>>{};
    for (final device in _devices) {
      // Une liaison prête n'est montrée qu'une fois identifiée (quelques dixièmes de
      // seconde) : sans cela, un téléphone branché qui passe en Wi-Fi apparaîtrait
      // brièvement en double.
      if (device.ready && !_identities.containsKey(device.serial)) continue;
      groups.putIfAbsent(_phoneIdOf(device), () => []).add(device);
    }
    _phones = [
      for (final entry in groups.entries)
        Phone(id: entry.key, name: _nameOf(entry.key, entry.value), links: entry.value),
    ];
    _dismissed.removeWhere((id) => !groups.containsKey(id));
    _notify();
    _maybeAutoStart();
  }

  String _nameOf(String id, List<AdbDevice> links) {
    for (final link in links) {
      final name = _identities[link.serial]?.name ?? '';
      if (name.isNotEmpty) return name;
    }
    for (final saved in _settings.wifi) {
      if (saved.name.isNotEmpty && (saved.id == id || links.any((l) => l.serial == saved.address))) return saved.name;
    }
    for (final link in links) {
      if (link.model.isNotEmpty) return link.model;
    }
    return 'Téléphone';
  }

  // ── Affichage ──

  void _maybeAutoStart() {
    if (_disposed || !_settings.autoStart || _session != null || !tools.complete) return;
    for (final phone in _phones) {
      final link = phone.bestLink;
      if (link == null || _dismissed.contains(phone.id)) continue;
      // On attend de connaître le nom du téléphone : il sert de titre à la fenêtre.
      if (!_identities.containsKey(link.serial)) continue;
      unawaited(startMirror(phone));
      return;
    }
  }

  /// Ouvre la fenêtre du téléphone.
  Future<void> startMirror(Phone phone) async {
    final link = phone.bestLink;
    if (link == null) {
      _setNotice(Notice('${phone.name} n\'est pas prêt.', error: true));
      return;
    }
    if (!tools.complete) {
      _setNotice(const Notice('Le programme scrcpy est introuvable : réinstallez sPhone.', error: true));
      return;
    }
    if (_session != null) await stopMirror();

    final session = MirrorSession(phoneId: phone.id, phoneName: phone.name, serial: link.serial, kind: link.kind);
    _session = session;
    _dismissed.remove(phone.id);
    _notice = null;
    _notify();

    try {
      final process = await startScrcpy(
        tools,
        buildScrcpyArgs(
          serial: link.serial,
          title: 'sPhone — ${phone.name}',
          settings: _settings,
          screenHeight: window.screenHeight,
        ),
        launcher: launcher,
      );
      session._process = process;
      final drained = Future.wait([_collect(process.stdout, session), _collect(process.stderr, session)]);
      unawaited(
        process.exitCode.then((code) async {
          // Le code de fin peut arriver avant les derniers messages d'erreur : on les attend.
          await drained.timeout(const Duration(seconds: 1), onTimeout: () => const []);
          await _onMirrorExit(session, code);
        }),
      );
    } on Object catch (error) {
      if (_session == session) _session = null;
      _dismissed.add(phone.id);
      _setNotice(Notice('Impossible de lancer l\'affichage : $error', error: true));
      return;
    }

    if (_settings.minimize) {
      unawaited(
        Future<void>.delayed(minimizeDelay).then((_) async {
          if (_disposed || _session != session) return;
          session._minimized = true;
          await window.minimize();
        }),
      );
    }
  }

  /// Conserve les dernières lignes écrites par scrcpy ; le futur se termine avec le flux.
  Future<void> _collect(Stream<List<int>> output, MirrorSession session) {
    return output
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
          session._log.add(line);
          if (session._log.length > 60) session._log.removeAt(0);
        }, onError: (Object _) {})
        .asFuture<void>()
        .catchError((Object _) {});
  }

  Future<void> _onMirrorExit(MirrorSession session, int code) async {
    if (_session != session) return;
    _session = null;
    if (_disposed) return;
    if (session._minimized) unawaited(window.restore());

    if (session._stoppedByUser || code == ScrcpyExit.closed) {
      _dismissed.add(session.phoneId);
      _notify();
    } else if (code == ScrcpyExit.disconnected) {
      _setNotice(Notice('La liaison avec ${session.phoneName} a été interrompue.'));
      // Une liaison qui tombe aussitôt établie ne doit pas relancer l'affichage en boucle.
      if (DateTime.now().difference(session._startedAt) < const Duration(seconds: 8)) {
        _dismissed.add(session.phoneId);
        return;
      }
      // Si le téléphone reste joignable par une autre liaison (câble débranché mais Wi-Fi
      // actif), l'affichage reprend dessus dès que la liste des liaisons est à jour.
      unawaited(Future<void>.delayed(const Duration(milliseconds: 1500)).then((_) => _maybeAutoStart()));
    } else {
      _dismissed.add(session.phoneId);
      // Un arrêt anormal après un long affichage n'est pas un échec de démarrage.
      final ranAWhile = DateTime.now().difference(session._startedAt) > const Duration(seconds: 20);
      _setNotice(
        Notice(
          ranAWhile
              ? 'L\'affichage de ${session.phoneName} s\'est arrêté de façon inattendue.'
              : describeStartFailure(session._log),
          error: true,
        ),
      );
    }
  }

  /// Ferme la fenêtre du téléphone.
  Future<void> stopMirror() async {
    final session = _session;
    if (session == null) return;
    session._stoppedByUser = true;
    final process = session._process;
    if (process == null) {
      _session = null;
      _notify();
      return;
    }
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      process.kill(ProcessSignal.sigkill);
    }
  }

  /// Vrai si l'écran de ce téléphone est affiché.
  bool isMirroring(Phone phone) => _session?.phoneId == phone.id;

  // ── Wi-Fi ──

  /// Rend un téléphone branché en USB joignable par le Wi-Fi, puis s'y connecte.
  Future<bool> enableWifi(Phone phone) async {
    final usb = phone.linkOf(LinkKind.usb, readyOnly: true);
    if (usb == null) {
      _setNotice(Notice('Branchez ${phone.name} en USB pour activer le Wi-Fi.', error: true));
      return false;
    }
    final key = 'wifi:${phone.id}';
    if (!_begin(key)) return false;
    try {
      var ip = parseWifiIp(await client.shell(usb.serial, 'ip route'));
      ip ??= parseWifiIp(await client.shell(usb.serial, 'ip -f inet addr show wlan0'));
      if (ip == null) {
        _setNotice(
          Notice(
            '${phone.name} n\'est connecté à aucun réseau Wi-Fi. Activez le Wi-Fi du téléphone puis réessayez.',
            error: true,
          ),
        );
        return false;
      }
      final address = '$ip:5555';
      // Déjà à l'écoute (activé plus tôt) ? On évite alors de redémarrer la liaison USB.
      var outcome = await _tryConnect(address, timeout: const Duration(seconds: 4));
      if (!outcome.ok) {
        await client.run(usb.serial, 'tcpip:5555');
        for (var attempt = 0; attempt < 10 && !outcome.ok; attempt++) {
          await Future<void>.delayed(wifiRetryDelay);
          outcome = await _tryConnect(address, timeout: const Duration(seconds: 6));
        }
      }
      if (!outcome.ok) {
        _setNotice(Notice(outcome.message, error: true));
        return false;
      }
      await _rememberWifi(WifiAddress(address: address, name: phone.name, id: phone.id));
      _setNotice(Notice('Wi-Fi activé pour ${phone.name} : vous pouvez débrancher le câble.'));
      return true;
    } on AdbException catch (error) {
      _setNotice(Notice('Activation du Wi-Fi impossible : ${error.message}', error: true));
      return false;
    } finally {
      _end(key);
    }
  }

  Future<AdbOutcome> _tryConnect(String address, {required Duration timeout}) async {
    try {
      return parseConnectReply(await client.hostRequest('host:connect:$address', timeout: timeout), address);
    } on AdbException catch (error) {
      return AdbOutcome(false, 'Connexion à $address impossible : ${error.message}');
    }
  }

  /// Se connecte à un téléphone par son adresse (`192.168.1.20` ou `192.168.1.20:5555`).
  Future<bool> connectAddress(String input, {String name = '', bool remember = true}) async {
    final address = normalizeAddress(input);
    if (address == null) {
      _setNotice(const Notice('Adresse invalide. Exemple : 192.168.1.20 ou 192.168.1.20:5555', error: true));
      return false;
    }
    final key = 'connect:$address';
    if (!_begin(key)) return false;
    try {
      final outcome = await _tryConnect(address, timeout: const Duration(seconds: 15));
      if (outcome.ok && remember) {
        // Une adresse déjà mémorisée garde le nom et l'identité du téléphone.
        final known = _settings.wifi.where((w) => w.address == address).firstOrNull;
        await _rememberWifi(
          WifiAddress(address: address, name: name.isNotEmpty ? name : known?.name ?? '', id: known?.id ?? ''),
        );
      }
      _setNotice(Notice(outcome.message, error: !outcome.ok));
      return outcome.ok;
    } finally {
      _end(key);
    }
  }

  /// Associe le PC à un téléphone avec le code à six chiffres du débogage sans fil.
  Future<bool> pair(String addressInput, String codeInput) async {
    final code = codeInput.replaceAll(RegExp(r'\s'), '');
    final address = addressInput.contains(':') ? normalizeAddress(addressInput) : null;
    if (address == null) {
      _setNotice(
        const Notice(
          'Indiquez l\'adresse et le port affichés sur le téléphone. Exemple : 192.168.1.20:37123',
          error: true,
        ),
      );
      return false;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      _setNotice(const Notice('Le code d\'association comporte six chiffres.', error: true));
      return false;
    }
    if (!_begin('pair')) return false;
    try {
      final outcome = parsePairReply(
        await client.hostRequest('host:pair:$code:$address', timeout: const Duration(seconds: 20)),
      );
      if (!outcome.ok) {
        _setNotice(Notice(outcome.message, error: true));
        return false;
      }
      // Une fois associé, le téléphone annonce son service de connexion : on s'y relie.
      final host = address.substring(0, address.lastIndexOf(':'));
      for (var attempt = 0; attempt < 6; attempt++) {
        await Future<void>.delayed(wifiRetryDelay);
        if (_phones.any((phone) => phone.hasWifi && phone.links.any((l) => l.serial.contains(host)))) break;
        await refreshNearby();
        final service = _nearby.where((s) => !s.pairing && s.host == host).firstOrNull;
        if (service != null && (await _tryConnect(service.address, timeout: const Duration(seconds: 6))).ok) break;
      }
      _setNotice(
        const Notice(
          'Téléphone associé. S\'il n\'apparaît pas dans la liste, connectez-vous avec l\'adresse affichée '
          'sur l\'écran « Débogage sans fil ».',
        ),
      );
      return true;
    } on AdbException catch (error) {
      _setNotice(Notice('Association impossible : ${error.message}', error: true));
      return false;
    } finally {
      _end('pair');
    }
  }

  /// Actualise la liste des téléphones qui s'annoncent sur le réseau.
  Future<void> refreshNearby() async {
    List<NearbyService> found;
    try {
      found = parseMdnsServices(await client.hostRequest('host:mdns:services', timeout: const Duration(seconds: 3)));
    } on Object {
      found = const [];
    }
    final connected = {for (final d in _devices) d.serial};
    found = [
      for (final service in found)
        if (service.pairing ||
            !(connected.contains(service.address) || connected.any((s) => s.startsWith(service.name))))
          service,
    ];
    final same =
        found.length == _nearby.length &&
        [for (var i = 0; i < found.length; i++) found[i].address == _nearby[i].address].every((equal) => equal);
    if (same) return;
    _nearby = found;
    _notify();
  }

  Future<void> _rememberWifi(WifiAddress entry) async {
    final others = [
      for (final saved in _settings.wifi)
        if (saved.address != entry.address && (entry.id.isEmpty || saved.id != entry.id)) saved,
    ];
    await updateSettings(_settings.copyWith(wifi: [...others, entry]));
  }

  /// Oublie une adresse Wi-Fi et coupe la liaison correspondante.
  Future<void> forgetWifi(WifiAddress entry) async {
    await updateSettings(
      _settings.copyWith(
        wifi: [
          for (final w in _settings.wifi)
            if (w.address != entry.address) w,
        ],
      ),
    );
    try {
      await client.hostRequest('host:disconnect:${entry.address}', timeout: const Duration(seconds: 4));
    } on Object {
      // Déjà déconnecté.
    }
  }

  /// Vrai si une liaison est établie avec cette adresse.
  bool isConnected(WifiAddress entry) => _devices.any((d) => d.serial == entry.address && d.ready);

  Future<void> _reconnectSaved() async {
    for (final saved in _settings.wifi) {
      if (_disposed) return;
      if (_devices.any((d) => d.serial == saved.address)) continue;
      await _tryConnect(saved.address, timeout: const Duration(seconds: 6));
    }
  }

  // ── Actions sur le téléphone ──

  /// Enregistre une capture de l'écran du téléphone dans le dossier Images du PC.
  /// Renvoie le chemin du fichier, ou `null` en cas d'échec.
  Future<String?> takeScreenshot(Phone phone) async {
    final link = phone.bestLink;
    if (link == null) return null;
    final key = 'shot:${phone.id}';
    if (!_begin(key)) return null;
    try {
      final bytes = await client.run(link.serial, 'exec:screencap -p', timeout: const Duration(seconds: 20));
      const png = [0x89, 0x50, 0x4E, 0x47];
      if (bytes.length < 8 || !listEquals(bytes.sublist(0, 4), png)) {
        _setNotice(const Notice('La capture a échoué : le téléphone n\'a pas renvoyé d\'image.', error: true));
        return null;
      }
      final folder = _screenshotDirectory();
      await folder.create(recursive: true);
      final file = File(p.join(folder.path, 'sPhone_${_timestamp(DateTime.now())}.png'));
      await file.writeAsBytes(bytes, flush: true);
      _setNotice(Notice('Capture enregistrée : ${file.path}'));
      return file.path;
    } on Object catch (error) {
      _setNotice(Notice('La capture a échoué : ${error is AdbException ? error.message : error}', error: true));
      return null;
    } finally {
      _end(key);
    }
  }

  /// Ouvre sur le téléphone l'écran de réglage du clavier physique (disposition AZERTY).
  Future<void> openKeyboardSettings(Phone phone) async {
    final link = phone.bestLink;
    if (link == null) return;
    try {
      await client.shell(link.serial, 'am start -a android.settings.HARD_KEYBOARD_SETTINGS');
      _setNotice(Notice('Réglage du clavier ouvert sur ${phone.name}.'));
    } on AdbException catch (error) {
      _setNotice(Notice('Ouverture impossible : ${error.message}', error: true));
    }
  }

  // ── Réglages et messages ──

  Future<void> updateSettings(Settings settings) async {
    _settings = settings;
    _notify();
    await _store.save(settings);
    _maybeAutoStart();
  }

  void clearNotice() {
    if (_notice == null) return;
    _notice = null;
    _notify();
  }

  void _setNotice(Notice notice) {
    _notice = notice;
    _notify();
  }

  bool _begin(String key) {
    if (!_busy.add(key)) return false;
    _notify();
    return true;
  }

  void _end(String key) {
    _busy.remove(key);
    _notify();
  }

  /// État imposé, pour les tests d'affichage et les captures de la documentation.
  @visibleForTesting
  void debugSetState({ServiceState? service, String? serviceError, MirrorSession? session, Notice? notice}) {
    if (service != null) _service = service;
    _serviceError = serviceError;
    _session = session;
    _notice = notice;
    notifyListeners();
  }
}

String _timestamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)}_${two(t.hour)}-${two(t.minute)}-${two(t.second)}';
}

/// Dossier des captures : `Images\sPhone` dans le profil de l'utilisateur.
Directory defaultScreenshotDirectory() {
  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path;
  return Directory(p.join(home, 'Pictures', 'sPhone'));
}
