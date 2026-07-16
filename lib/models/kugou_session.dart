class KugouSession {
  const KugouSession({
    this.token = '',
    this.userId = '',
    this.dfid = '',
    this.mid = '',
    this.guid = '',
    this.device = '',
    this.mac = '',
    this.nickname = '',
    this.avatarUrl = '',
  });

  final String token;
  final String userId;
  final String dfid;
  final String mid;
  final String guid;
  final String device;
  final String mac;
  final String nickname;
  final String avatarUrl;

  bool get isLoggedIn => token.isNotEmpty && userId.isNotEmpty;
  bool get hasDevice => dfid.isNotEmpty;

  String get displayName {
    if (!isLoggedIn) return '登录';
    return nickname.isEmpty ? '已登录' : nickname;
  }

  String get authorization {
    final values = <String, String>{
      'token': token,
      'userid': userId,
      'dfid': dfid,
      'KUGOU_API_MID': mid,
      'uuid': guid,
      'KUGOU_API_GUID': guid,
      'KUGOU_API_DEV': device,
      'KUGOU_API_MAC': mac,
    };
    return values.entries
        .where((entry) => entry.value.isNotEmpty)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(';');
  }

  KugouSession copyWith({
    String? token,
    String? userId,
    String? dfid,
    String? mid,
    String? guid,
    String? device,
    String? mac,
    String? nickname,
    String? avatarUrl,
  }) {
    return KugouSession(
      token: token ?? this.token,
      userId: userId ?? this.userId,
      dfid: dfid ?? this.dfid,
      mid: mid ?? this.mid,
      guid: guid ?? this.guid,
      device: device ?? this.device,
      mac: mac ?? this.mac,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  KugouSession loggedOut() {
    return KugouSession(
      dfid: dfid,
      mid: mid,
      guid: guid,
      device: device,
      mac: mac,
    );
  }

  Map<String, Object?> toJson() => {
    'token': token,
    'userId': userId,
    'dfid': dfid,
    'mid': mid,
    'guid': guid,
    'device': device,
    'mac': mac,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
  };

  factory KugouSession.fromJson(Map<String, Object?> json) {
    String read(String key) => json[key]?.toString() ?? '';
    return KugouSession(
      token: read('token'),
      userId: read('userId'),
      dfid: read('dfid'),
      mid: read('mid'),
      guid: read('guid'),
      device: read('device'),
      mac: read('mac'),
      nickname: read('nickname'),
      avatarUrl: read('avatarUrl'),
    );
  }
}
