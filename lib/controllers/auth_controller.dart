import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/kugou_session.dart';
import '../services/kugou_api_client.dart';

enum AuthState {
  initializing,
  loggedOut,
  loadingQr,
  waitingScan,
  waitingConfirm,
  loggedIn,
  expired,
  error,
}

class AuthController extends ChangeNotifier {
  AuthController(this.apiClient);

  final KugouApiClient apiClient;

  AuthState state = AuthState.initializing;
  String? qrImageDataUrl;
  String? errorText;
  int? lastQrStatus;
  Timer? _pollTimer;
  bool _checking = false;
  String? _qrKey;

  KugouSession get session => apiClient.session;
  bool get isLoggedIn => session.isLoggedIn;

  Future<void> initialize() async {
    state = AuthState.initializing;
    notifyListeners();
    try {
      await apiClient.initialize();
      state = isLoggedIn ? AuthState.loggedIn : AuthState.loggedOut;
    } on KugouApiException catch (error) {
      state = AuthState.error;
      errorText = error.message;
    } catch (_) {
      state = AuthState.error;
      errorText = '初始化登录服务失败';
    }
    notifyListeners();
  }

  Future<void> startQrLogin() async {
    _pollTimer?.cancel();
    state = AuthState.loadingQr;
    qrImageDataUrl = null;
    errorText = null;
    lastQrStatus = null;
    notifyListeners();

    try {
      if (!apiClient.session.hasDevice) await apiClient.registerDevice();
      final qr = await apiClient.createLoginQr();
      _qrKey = qr.key;
      qrImageDataUrl = qr.imageDataUrl;
      state = AuthState.waitingScan;
      notifyListeners();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _checkQr(),
      );
    } on KugouApiException catch (error) {
      state = AuthState.error;
      errorText = error.message;
      notifyListeners();
    } catch (_) {
      state = AuthState.error;
      errorText = '二维码加载失败，请稍后重试';
      notifyListeners();
    }
  }

  Future<void> _checkQr() async {
    final key = _qrKey;
    if (key == null || _checking) return;
    _checking = true;
    try {
      final result = await apiClient.checkLoginQr(key);
      lastQrStatus = result.status;
      switch (result.status) {
        case 4:
          _pollTimer?.cancel();
          state = AuthState.loggedIn;
          break;
        case 2:
          state = AuthState.waitingConfirm;
          break;
        case 0:
          _pollTimer?.cancel();
          state = AuthState.expired;
          break;
        default:
          state = AuthState.waitingScan;
      }
      notifyListeners();
    } catch (_) {
      _pollTimer?.cancel();
      state = AuthState.error;
      errorText = '登录状态检查失败，请重新获取二维码';
      notifyListeners();
    } finally {
      _checking = false;
    }
  }

  Future<void> logout() async {
    _pollTimer?.cancel();
    await apiClient.logout();
    qrImageDataUrl = null;
    errorText = null;
    state = AuthState.loggedOut;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
