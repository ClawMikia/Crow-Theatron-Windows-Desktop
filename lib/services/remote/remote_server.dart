// Conditional export: real TCP/UDP server on desktop (dart:io),
// inert no-op stub on Web (no sockets available in the browser).
export 'remote_server_stub.dart' if (dart.library.io) 'remote_server_io.dart';
