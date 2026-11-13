import 'dart:io';

import 'package:flutter/foundation.dart';

/// 테스트에서 안드로이드 화면·흐름을 확인할 때만 true/false로 바꿉니다. (평소에는 null = 진짜 기기 종류)
bool? debugPretendAndroid;

/// 지금 기기가 안드로이드인지. 안드로이드는 앱을 지우면 앱 안 자료도 함께 지워져요.
bool get isAndroidDevice => debugPretendAndroid ?? (!kIsWeb && Platform.isAndroid);
