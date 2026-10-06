import 'package:firebase_core/firebase_core.dart';

/// Cấu hình Firebase cho bản web (Firebase Console → Project settings →
/// Your apps → Math Jump Web). Các giá trị này là công khai, được phép nằm
/// trong mã nguồn; dữ liệu được bảo vệ bằng firestore.rules.
const webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyDuZqpU2OsdyD87bBZuLIhyekV_gMAme3M',
  appId: '1:646653196426:web:6d060def2aa22a7488d573',
  messagingSenderId: '646653196426',
  projectId: 'mathjump-861ff',
  authDomain: 'mathjump-861ff.firebaseapp.com',
  storageBucket: 'mathjump-861ff.firebasestorage.app',
  measurementId: 'G-MW576D1YBD',
);

bool get webFirebaseConfigured => webFirebaseOptions.apiKey != 'REPLACE';

/// Khóa trang web (site key) reCAPTCHA v3 cho App Check trên bản web
/// (google.com/recaptcha/admin, tên miền phamtruongtung.github.io). Khóa này
/// công khai; khóa bí mật (secret key) chỉ dán vào Firebase Console.
/// Còn để REPLACE thì bản web chưa bật App Check.
const recaptchaSiteKey = '6LcBkOEtAAAAAIOaE18SPC_hT6v4dj8Ztqe3CpA2';
