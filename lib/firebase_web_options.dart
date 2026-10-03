import 'package:firebase_core/firebase_core.dart';

/// Cấu hình Firebase cho bản web (Firebase Console → Project settings →
/// Your apps → Web app → SDK setup and configuration → Config).
/// Các giá trị này là công khai, được phép nằm trong mã nguồn.
/// Còn để REPLACE thì bản web chạy ở chế độ khách (không đăng nhập).
const webFirebaseOptions = FirebaseOptions(
  apiKey: 'REPLACE',
  appId: 'REPLACE',
  messagingSenderId: 'REPLACE',
  projectId: 'REPLACE',
  authDomain: 'REPLACE',
  storageBucket: 'REPLACE',
);

bool get webFirebaseConfigured => webFirebaseOptions.apiKey != 'REPLACE';
