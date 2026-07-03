import 'dart:async';

class SessionExpiredService {
  SessionExpiredService._();

  static final _controller = StreamController<void>.broadcast();

  static Stream<void> get stream => _controller.stream;

  static void notify() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }
}
