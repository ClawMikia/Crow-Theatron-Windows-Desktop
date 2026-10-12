#!/usr/bin/env python3
"""
Crow-Chap Bluetooth bridge (optional, PC side).

Advertises a Bluetooth RFCOMM service and relays bytes between the phone
and Crow Theatron's local TCP server (127.0.0.1:8765). The protocol is the
same newline-delimited JSON, so PIN / token pairing works unchanged.

Setup (Windows):
    1. Pair the phone and PC in Windows / Android Bluetooth settings.
    2. pip install pybluez2
    3. Enable "Remote control (phone)" in Crow Theatron -> Settings.
    4. python bt_bridge.py
    5. In Crow-Chap tap BLUETOOTH and pick this PC.

Wi-Fi is the primary, recommended connection; this is a fallback.
"""
import socket
import threading

import bluetooth  # pybluez2

SERVICE_UUID = "7c0a1f55-5b0e-4c1a-9d6b-3b2a6f4e8c11"  # must match Crow-Chap
TCP_HOST, TCP_PORT = "127.0.0.1", 8765


def pump(src, dst):
    try:
        while True:
            data = src.recv(4096)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        for s in (src, dst):
            try:
                s.close()
            except OSError:
                pass


def main():
    server = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
    server.bind(("", bluetooth.PORT_ANY))
    server.listen(1)
    bluetooth.advertise_service(
        server,
        "CrowChap",
        service_id=SERVICE_UUID,
        service_classes=[SERVICE_UUID, bluetooth.SERIAL_PORT_CLASS],
        profiles=[bluetooth.SERIAL_PORT_PROFILE],
    )
    print("Crow-Chap Bluetooth bridge waiting on RFCOMM channel", server.getsockname()[1])
    while True:
        phone, addr = server.accept()
        print("Phone connected:", addr)
        try:
            pc = socket.create_connection((TCP_HOST, TCP_PORT), timeout=5)
            pc.settimeout(None)
        except OSError as e:
            print("Crow Theatron server not reachable:", e)
            phone.close()
            continue
        threading.Thread(target=pump, args=(phone, pc), daemon=True).start()
        threading.Thread(target=pump, args=(pc, phone), daemon=True).start()


if __name__ == "__main__":
    main()
