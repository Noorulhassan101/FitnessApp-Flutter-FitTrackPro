import 'dart:async';
import 'dart:developer';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/firebase_options.dart';

Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      if (e.toString().contains('duplicate-app') || e.toString().contains('already exists')) {
        log('Firebase already initialized natively, ignoring: $e');
      } else {
        rethrow;
      }
    }

    FlutterError.onError = (details) {
      log(details.exceptionAsString(), stackTrace: details.stack);
    };

    runApp(
      ProviderScope(
        child: await builder(),
      ),
    );
  } catch (e, stack) {
    log('FATAL ERROR DURING BOOTSTRAP: $e', stackTrace: stack);
    print('FATAL ERROR DURING BOOTSTRAP: $e');
    runApp(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Text('FATAL ERROR: $e', style: TextStyle(color: Color(0xFFFF0000))),
      ),
    );
  }
}
