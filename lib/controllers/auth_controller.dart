import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/kugou_session.dart';
import '../services/kugou_api_client.dart';

enum AuthState {
  initializing,
  loggedOut,
  loadingQr,
  loadingWx,
  waitingScan,
  waitingConfirm,
  sendingSms,
  smsReady,
  smsLoggingIn,
  loggedIn,
  expired,
  error,
}

enum LoginMethod { qrcode, sms, wechat }

class AuthController extends ChangeNotifier {
  AuthController(this.apiClient);

  final KugouApiClient apiClient;

  AuthState state = AuthState.initializing;
  LoginMethod method = LoginMethod.qrcode;
  String? qrImageDataUrl;
  String? qrText;
  String? wxImageDataUrl;
  String? wxText;
  String? errorText;
  int? lastQrStatus;
  int? lastWxStatus;
  int smsCountdown = 0;
  Timer? _pollTimer;
  Timer? _smsTimer;
  bool _checking = false;
  String? _qrKey;
  String? _wxUuid;

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
    method = LoginMethod.qrcode;
    _pollTimer?.cancel();
    state = AuthState.loadingQr;
    qrImageDataUrl = null;
    qrText = null;
    errorText = null;
    lastQrStatus = null;
    notifyListeners();

    try {
      if (!apiClient.session.hasDevice) await apiClient.registerDevice();
      final qr = await apiClient.createLoginQr();
      _qrKey = qr.key;
      qrImageDataUrl = qr.imageDataUrl;
      qrText = qr.qrText;
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

  Future<void> startWxLogin() async {
    method = LoginMethod.wechat;
    _pollTimer?.cancel();
    state = AuthState.loadingWx;
    wxImageDataUrl = null;
    wxText = null;
    errorText = null;
    lastWxStatus = null;
    notifyListeners();

    try {
      final wx = await apiClient.createWxLogin();
      _wxUuid = wx.uuid;
      wxImageDataUrl = wx.imageDataUrl;
      wxText = wx.qrText;
      state = AuthState.waitingScan;
      notifyListeners();
      _pollTimer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => _checkWx(),
      );
    } on KugouApiException catch (error) {
      state = AuthState.error;
      errorText = error.message;
      notifyListeners();
    } catch (_) {
      state = AuthState.error;
      errorText = '微信二维码加载失败，请稍后重试';
      notifyListeners();
    }
  }

  void showSmsLogin() {
    method = LoginMethod.sms;
    _pollTimer?.cancel();
    state = AuthState.smsReady;
    errorText = null;
    notifyListeners();
  }

  Future<void> sendSmsCode(String mobile) async {
    method = LoginMethod.sms;
    _pollTimer?.cancel();
    state = AuthState.sendingSms;
    errorText = null;
    notifyListeners();
    try {
      if (!apiClient.session.hasDevice) await apiClient.registerDevice();
      await apiClient.sendSmsCode(mobile);
      _startSmsCountdown();
      state = AuthState.smsReady;
      notifyListeners();
    } on KugouApiException catch (error) {
      state = AuthState.smsReady;
      errorText = error.message;
      notifyListeners();
    } catch (_) {
      state = AuthState.smsReady;
      errorText = '验证码发送失败，请稍后重试';
      notifyListeners();
    }
  }

  Future<void> loginBySms(String mobile, String code) async {
    method = LoginMethod.sms;
    _pollTimer?.cancel();
    state = AuthState.smsLoggingIn;
    errorText = null;
    notifyListeners();
    try {
      await apiClient.loginBySms(mobile, code);
      _smsTimer?.cancel();
      smsCountdown = 0;
      state = AuthState.loggedIn;
      notifyListeners();
    } on KugouApiException catch (error) {
      state = AuthState.smsReady;
      errorText = error.message;
      notifyListeners();
    } catch (_) {
      state = AuthState.smsReady;
      errorText = '登录失败，请稍后重试';
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

  Future<void> _checkWx() async {
    final uuid = _wxUuid;
    if (uuid == null || _checking) return;
    _checking = true;
    try {
      final result = await apiClient.checkWxLogin(uuid);
      lastWxStatus = result.status;
      if (result.status == 405 && result.openCode?.isNotEmpty == true) {
        _pollTimer?.cancel();
        await apiClient.loginByOpenPlat(result.openCode!);
        state = AuthState.loggedIn;
      } else if (result.status == 404 || result.status == 408) {
        state = AuthState.waitingScan;
      } else if (result.status == 402 || result.status == 403) {
        _pollTimer?.cancel();
        state = AuthState.expired;
      } else {
        state = AuthState.waitingScan;
      }
      notifyListeners();
    } catch (_) {
      _pollTimer?.cancel();
      state = AuthState.error;
      errorText = '微信登录状态检查失败，请重新获取二维码';
      notifyListeners();
    } finally {
      _checking = false;
    }
  }

  void _startSmsCountdown() {
    _smsTimer?.cancel();
    smsCountdown = 60;
    _smsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (smsCountdown <= 1) {
        smsCountdown = 0;
        timer.cancel();
      } else {
        smsCountdown -= 1;
      }
      notifyListeners();
    });
  }

  Future<void> logout() async {
    _pollTimer?.cancel();
    _smsTimer?.cancel();
    await apiClient.logout();
    qrImageDataUrl = null;
    qrText = null;
    wxImageDataUrl = null;
    wxText = null;
    errorText = null;
    smsCountdown = 0;
    lastQrStatus = null;
    lastWxStatus = null;
    state = AuthState.loggedOut;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _smsTimer?.cancel();
    super.dispose();
  }
}
