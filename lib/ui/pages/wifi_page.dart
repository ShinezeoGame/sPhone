import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/phone.dart';
import '../../state/phone_controller.dart';
import '../../state/phone_scope.dart';
import '../theme.dart';
import '../widgets/controls.dart';
import '../widgets/tiles.dart';
import 'page_scaffold.dart';

/// Connexion d'un téléphone en Wi-Fi : avec le câble (le plus simple), sans câble
/// (débogage sans fil d'Android 11+), ou par une adresse déjà connue.
class WifiPage extends StatefulWidget {
  const WifiPage({super.key});

  @override
  State<WifiPage> createState() => _WifiPageState();
}

class _WifiPageState extends State<WifiPage> {
  final _pairAddress = TextEditingController();
  final _pairCode = TextEditingController();
  final _address = TextEditingController();
  Timer? _timer;
  PhoneController? _controller;
  bool _connecting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    final controller = _controller = PhoneScope.read(context);
    // Tant que la page est ouverte, on guette les téléphones qui s'annoncent sur le réseau.
    unawaited(controller.refreshNearby());
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => controller.refreshNearby());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pairAddress.dispose();
    _pairCode.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final ok = await _controller!.pair(_pairAddress.text, _pairCode.text);
    if (ok && mounted) _pairCode.clear();
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    final ok = await _controller!.connectAddress(_address.text);
    if (!mounted) return;
    setState(() => _connecting = false);
    if (ok) _address.clear();
  }

  @override
  Widget build(BuildContext context) {
    final controller = PhoneScope.of(context);
    final t = context.text;
    final usbPhones = controller.phones.where((p) => p.hasUsb).toList();
    final pairing = controller.nearby.where((s) => s.pairing).toList();
    final connectable = controller.nearby.where((s) => !s.pairing).toList();

    // Le téléphone affiche l'écran d'association : son adresse est préremplie.
    if (pairing.isNotEmpty && _pairAddress.text.isEmpty) {
      _pairAddress.text = pairing.first.address;
    }

    return AppPage(
      header: const PageHeader(title: 'Connexion Wi-Fi'),
      children: [
        const NoticeArea(),
        Text('Le téléphone et le PC doivent être sur le même réseau Wi-Fi.', style: t.secondary),

        const SectionTitle('Avec le câble', detail: 'le plus simple'),
        Tile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const StepList([
                'Branchez le téléphone en USB.',
                'Cliquez sur le bouton ci-dessous.',
                'Débranchez le câble : l\'écran reste accessible par le Wi-Fi.',
              ]),
              const SizedBox(height: 14),
              if (usbPhones.isEmpty)
                const AppButton(
                  label: 'Aucun téléphone branché en USB',
                  icon: Icons.usb_off_rounded,
                  expand: true,
                  onPressed: null,
                )
              else
                for (final phone in usbPhones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppButton(
                      label: phone.hasWifi ? '${phone.name} : Wi-Fi déjà actif' : 'Activer le Wi-Fi sur ${phone.name}',
                      icon: Icons.wifi_rounded,
                      kind: phone.hasWifi ? ButtonKind.secondary : ButtonKind.primary,
                      expand: true,
                      busy: controller.isBusy('wifi:${phone.id}'),
                      onPressed: phone.hasWifi ? null : () => controller.enableWifi(phone),
                    ),
                  ),
              const SizedBox(height: 4),
              Text('À refaire après un redémarrage du téléphone.', style: t.caption),
            ],
          ),
        ),

        const SectionTitle('Sans câble', detail: 'débogage sans fil'),
        Tile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const StepList([
                'Sur le téléphone : Paramètres → Options de développement → Débogage sans fil, et activez-le.',
                'Touchez « Associer l\'appareil avec un code d\'association ».',
                'Recopiez ici l\'adresse et le code affichés, puis cliquez sur Associer.',
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: _pairAddress,
                style: t.body,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Adresse IP et port', hintText: '192.168.1.20:37123'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _pairCode,
                      style: t.body,
                      keyboardType: TextInputType.number,
                      onSubmitted: (_) => _pair(),
                      decoration: const InputDecoration(labelText: 'Code', hintText: '123456'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AppButton(
                    label: 'Associer',
                    kind: ButtonKind.primary,
                    busy: controller.isBusy('pair'),
                    onPressed: _pair,
                  ),
                ],
              ),
              if (connectable.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Détectés sur le réseau', style: t.itemTitle),
                const SizedBox(height: 4),
                for (final service in connectable) _NearbyRow(service: service),
              ],
            ],
          ),
        ),

        const SectionTitle('Par son adresse'),
        Tile(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Si le téléphone est déjà prêt pour le Wi-Fi, son adresse suffit. Elle figure dans '
                'Paramètres → À propos du téléphone → Informations sur l\'état.',
                style: t.secondary,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _address,
                      style: t.body,
                      keyboardType: TextInputType.url,
                      onSubmitted: (_) => _connect(),
                      decoration: const InputDecoration(labelText: 'Adresse IP', hintText: '192.168.1.20'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  AppButton(label: 'Connecter', busy: _connecting, onPressed: _connect),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Un téléphone détecté sur le réseau, prêt à être connecté.
class _NearbyRow extends StatelessWidget {
  const _NearbyRow({required this.service});

  final NearbyService service;

  @override
  Widget build(BuildContext context) {
    final controller = PhoneScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.wifi_tethering_rounded, size: 20, color: context.colors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(service.address, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.body),
          ),
          AppButton(
            label: 'Connecter',
            compact: true,
            busy: controller.isBusy('connect:${service.address}'),
            onPressed: () => controller.connectAddress(service.address, remember: false),
          ),
        ],
      ),
    );
  }
}
