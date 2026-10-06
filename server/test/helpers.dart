import 'dart:convert';

import 'package:analytic_server/analytic_server.dart';

RawEvent ev(String day, int ts, String name, String user,
        [Map<String, Object?> params = const {}]) =>
    RawEvent(
      day: day,
      tsMicros: ts,
      eventName: name,
      userPseudoId: user,
      paramsJson: jsonEncode(params),
      userPropsJson: '{}',
      platform: 'ANDROID',
      appVersion: '1.0.0',
    );
