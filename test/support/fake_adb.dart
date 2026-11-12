import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Faux service adb pour les tests : parle le même protocole que le vrai sur un port local.
class FakeAdb {
  FakeAdb._(this._server) {
    _server.listen(_serve);
  }

  static Future<FakeAdb> start() => startOn(0);

  /// Démarre sur un port précis (0 : un port libre quelconque).
  static Future<FakeAdb> startOn(int port) async =>
      FakeAdb._(await ServerSocket.bind(InternetAddress.loopbackIPv4, port));

  final ServerSocket _server;
  final List<Socket> _trackers = [];
  final List<Socket> _sockets = [];

  int get port => _server.port;

  /// Toutes les requêtes reçues, dans l'ordre (`host:…`, `shell:…`).
  final List<String> requests = [];

  String _devices = '';

  /// Réponse à `host:mdns:services`.
  String mdns = '';

  /// Réponses aux commandes `shell:` : la première clé contenue dans la commande l'emporte.
  final Map<String, String> shell = {};

  /// Réponse à `exec:` (capture d'écran).
  Uint8List exec = Uint8List(0);

  /// Réponse à `host:connect:<adresse>`.
  String Function(String address) onConnect = (address) => 'connected to $address';

  /// Réponse à `host:pair:<code>:<adresse>`.
  String Function(String code, String address) onPair = (code, address) =>
      'Successfully paired to $address [guid=adb-R5TEST-AbCdEf]';

  /// Appelé après `tcpip:5555`.
  void Function()? onTcpip;

  /// Change la liste des liaisons et prévient les clients qui la suivent.
  void setDevices(String text) {
    _devices = text;
    for (final tracker in _trackers) {
      tracker.add(_block(text));
    }
  }

  Future<void> close() async {
    for (final socket in [..._sockets]) {
      socket.destroy();
    }
    await _server.close();
  }

  static List<int> _block(String text) {
    final payload = utf8.encode(text);
    return [...ascii.encode(payload.length.toRadixString(16).padLeft(4, '0')), ...payload];
  }

  void _serve(Socket socket) {
    _sockets.add(socket);
    final buffer = <int>[];
    String? transport;
    var finished = false;

    void okay([String? block]) {
      socket.add(ascii.encode('OKAY'));
      if (block != null) socket.add(_block(block));
    }

    void end() {
      finished = true;
      unawaited(socket.flush().then((_) => socket.destroy()).catchError((Object _) {}));
    }

    void handle(String request) {
      requests.add(request);
      if (transport != null) {
        okay();
        if (request.startsWith('shell:')) {
          final command = request.substring(6);
          final key = shell.keys.where(command.contains).firstOrNull;
          socket.add(utf8.encode(key == null ? '' : shell[key]!));
        } else if (request.startsWith('exec:')) {
          socket.add(exec);
        } else if (request.startsWith('tcpip:')) {
          socket.add(utf8.encode('restarting in TCP mode port: ${request.substring(6)}\n'));
          onTcpip?.call();
        }
        end();
        return;
      }
      if (request == 'host:version') {
        okay('0029');
        end();
      } else if (request == 'host:devices-l') {
        okay(_devices);
        end();
      } else if (request == 'host:track-devices-l') {
        okay(_devices);
        _trackers.add(socket);
      } else if (request == 'host:mdns:services') {
        okay(mdns);
        end();
      } else if (request.startsWith('host:connect:')) {
        okay(onConnect(request.substring(13)));
        end();
      } else if (request.startsWith('host:disconnect:')) {
        okay('disconnected ${request.substring(16)}');
        end();
      } else if (request.startsWith('host:pair:')) {
        final rest = request.substring(10);
        final cut = rest.indexOf(':');
        okay(onPair(rest.substring(0, cut), rest.substring(cut + 1)));
        end();
      } else if (request.startsWith('host:transport:')) {
        final serial = request.substring(15);
        if (_devices.split('\n').any((line) => line.startsWith('$serial ') || line.startsWith('$serial\t'))) {
          transport = serial;
          okay();
        } else {
          socket.add(ascii.encode('FAIL'));
          socket.add(_block("device '$serial' not found"));
          end();
        }
      } else if (request == 'host:kill') {
        okay();
        end();
      } else {
        socket.add(ascii.encode('FAIL'));
        socket.add(_block('unknown host service'));
        end();
      }
    }

    socket.listen(
      (chunk) {
        buffer.addAll(chunk);
        while (!finished && buffer.length >= 4) {
          final length = int.parse(ascii.decode(buffer.sublist(0, 4)), radix: 16);
          if (buffer.length < 4 + length) break;
          final request = utf8.decode(buffer.sublist(4, 4 + length));
          buffer.removeRange(0, 4 + length);
          handle(request);
        }
      },
      onError: (Object _) {},
      onDone: () {
        _trackers.remove(socket);
        _sockets.remove(socket);
        socket.destroy();
      },
    );
  }
}
