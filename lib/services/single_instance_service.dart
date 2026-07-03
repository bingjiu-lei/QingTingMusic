import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SingleInstanceService {
  SingleInstanceService({required this.onShowRequested});

  static const int _port = 45521;
  static const String _message = 'show';

  final FutureOr<void> Function() onShowRequested;
  ServerSocket? _server;

  Future<bool> start() async {
    try {
      _server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _port,
        shared: false,
      );
      _server!.listen(_handleClient, onError: (_) {});
      return true;
    } on SocketException {
      return await _notifyExistingInstance();
    }
  }

  Future<void> _handleClient(Socket socket) async {
    try {
      final data = await utf8.decoder.bind(socket).join();
      if (data.trim() == _message) {
        await onShowRequested();
      }
    } finally {
      await socket.close();
    }
  }

  Future<bool> _notifyExistingInstance() async {
    Socket? socket;
    try {
      socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        _port,
        timeout: const Duration(milliseconds: 800),
      );
      socket.write(_message);
      await socket.flush();
      return false;
    } catch (_) {
      // If the old instance is shutting down, launching a new one is safer.
      return true;
    } finally {
      await socket?.close();
    }
  }

  Future<void> dispose() async {
    await _server?.close();
    _server = null;
  }
}
