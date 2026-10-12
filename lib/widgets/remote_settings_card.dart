import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/remote/remote_server.dart';
import '../theme/crow_colors.dart';

/// Settings → "Remote control (phone)". Enables the Crow-Chap server and
/// shows the PIN, this PC's addresses and a pairing QR code.
class RemoteSettingsCard extends StatelessWidget {
  const RemoteSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final r = context.watch<RemoteServer>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.phone_android_rounded, color: CrowColors.accentYellow),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Remote control (phone)',
                      style: TextStyle(color: CrowColors.onBg, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                if (r.supported)
                  Switch(
                    value: r.enabled,
                    activeColor: CrowColors.accentYellow,
                    onChanged: (v) => r.setEnabled(v),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (!r.supported)
              Text(r.lastError ?? 'Not available on this platform.',
                  style: const TextStyle(color: CrowColors.onMuted, fontSize: 12))
            else if (!r.enabled)
              const Text(
                'Turn this on to control Crow Théatron from the Crow-Chap Android app over your local Wi-Fi.',
                style: TextStyle(color: CrowColors.onMuted, fontSize: 12),
              )
            else ...[
              if (r.lastError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(r.lastError!, style: const TextStyle(color: CrowColors.accentRed, fontSize: 12)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: QrImageView(
                      data: r.pairingUri,
                      version: QrVersions.auto,
                      size: 150,
                      backgroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PIN', style: TextStyle(color: CrowColors.onMuted, fontSize: 12)),
                        Row(
                          children: [
                            SelectableText(
                              r.pin,
                              style: const TextStyle(
                                  color: CrowColors.accentYellow, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4),
                            ),
                            IconButton(
                              tooltip: 'New PIN',
                              icon: const Icon(Icons.refresh_rounded, color: CrowColors.accentCyan),
                              onPressed: r.regeneratePin,
                            ),
                            IconButton(
                              tooltip: 'Copy PIN',
                              icon: const Icon(Icons.copy_rounded, color: CrowColors.onMuted),
                              onPressed: () => Clipboard.setData(ClipboardData(text: r.pin)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text('Address (TCP ${RemoteServer.tcpPort})',
                            style: TextStyle(color: CrowColors.onMuted, fontSize: 12)),
                        if (r.addresses.isEmpty)
                          const Text('No network found', style: TextStyle(color: CrowColors.onBg))
                        else
                          for (final ip in r.addresses)
                            SelectableText('$ip : ${RemoteServer.tcpPort}',
                                style: const TextStyle(color: CrowColors.onBg, fontSize: 14)),
                        const SizedBox(height: 8),
                        Text('${r.clientCount} phone(s) connected  ·  ${r.pairedCount} paired',
                            style: const TextStyle(color: CrowColors.accentGreen, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: r.refreshAddresses,
                    icon: const Icon(Icons.network_check_rounded, size: 18),
                    label: const Text('Refresh addresses'),
                  ),
                  TextButton.icon(
                    onPressed: r.pairedCount == 0 && r.clientCount == 0 ? null : r.forgetAllDevices,
                    style: TextButton.styleFrom(foregroundColor: CrowColors.accentRed),
                    icon: const Icon(Icons.link_off_rounded, size: 18),
                    label: const Text('Forget all phones'),
                  ),
                ],
              ),
              const Text(
                'Windows Firewall: allow Crow Théatron on Private networks (TCP 8765, UDP 8766). '
                'Traffic is plain TCP on your LAN, protected by the PIN / pairing token — never expose port 8765 to the internet.',
                style: TextStyle(color: CrowColors.onMuted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
