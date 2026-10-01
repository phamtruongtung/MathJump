# 🐸 Math Jump

Game luyện cộng, trừ, nhân, chia cho trẻ em trên Android, viết bằng **Flutter**.

## Cách chơi

- Màn hình hiện một phép tính bị khuyết **một con số** hoặc **một dấu** (+ − × ÷), ví dụ `7 + ? = 12` hoặc `6 ? 3 = 2`.
- Chọn 1 trong 4 đáp án trước khi hết giờ. Mỗi câu đúng, nhân vật **nhảy lên một bậc thang**.
- Điểm mỗi câu: 10 điểm, cộng thêm tối đa 5 điểm nếu trả lời nhanh.
- Đủ điểm thì **lên level**: số lớn hơn, nhiều phép tính hơn, ít thời gian hơn, và cần nhiều điểm hơn để lên level kế tiếp.
- Chọn sai hoặc hết giờ là **game over**. Màn kết quả hiện điểm, level, thời gian sống và số câu đúng. Có pháo giấy nếu lập kỷ lục mới.

| Level | Phép tính | Phạm vi cộng/trừ | Thừa số nhân/chia | Thời gian/câu | Điểm để lên level |
|------:|-----------|-----------------:|------------------:|--------------:|------------------:|
| 1 | + | 0–10 | – | 10,0 s | 50 |
| 2 | + − | 0–25 | – | 9,3 s | 80 |
| 3 | + − × | 0–40 | 2–5 | 8,6 s | 110 |
| 4 | + − × ÷ | 0–55 | 2–6 | 7,9 s | 140 |
| 10 | + − × ÷ | 0–145 | 2–12 | 3,7 s | 320 |
| 11+ | + − × ÷ | tăng dần | tối đa 2–20 | 3,0 s | +30 mỗi level |

Có thể chỉnh các thông số này trong `LevelConfig` ([lib/game/question.dart](lib/game/question.dart)).

## Tính năng

- Giao diện màu tươi sáng, nút bấm to, 10 nhân vật để chọn (🐸 🐰 🐱 🐶 🐼 🦊 🐵 🐧 🦄 🐯).
- Có tiếng Việt và tiếng Anh, đổi được ngay trong Cài đặt hoặc ở màn hình đăng nhập.
- **Đăng nhập Facebook** (qua Firebase Auth). Ngoài ra còn có **chế độ khách** để chơi ngay. Khi đăng nhập lần đầu, thành tích chơi ở chế độ khách được chuyển sang tài khoản.
- **Chơi offline hoàn toàn**: lịch sử, kỷ lục và bảng xếp hạng bạn bè (bản lưu gần nhất) đều nằm trên máy. Khi có mạng trở lại, app tự đẩy kỷ lục lên và tải điểm mới của bạn bè về.
- **Kết bạn bằng mã 6 ký tự**: gửi lời mời, bạn kia đồng ý hoặc từ chối, hủy kết bạn. Bảng xếp hạng gồm bạn bè và chính mình. Màn kết quả báo khi bạn vừa vượt qua ai đó.
- **Khoe lên Facebook**: chọn 1 trong vài lời khoe gợi ý, app chụp bảng kết quả thành ảnh rồi mở bảng chia sẻ (chọn Facebook).
  > Chính sách của Facebook **không cho app điền sẵn nội dung bài đăng**, nên app sẽ **sao chép lời khoe vào clipboard**. Người chơi chỉ cần dán vào ô nội dung.
- Tự tạm dừng khi chuyển sang app khác. Có nút tạm dừng, và khi đang tạm dừng thì câu hỏi bị che lại để không ăn gian.

## Cài đặt & chạy

### 1. Cài công cụ (một lần)
1. Cài [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/mobile) và thêm `flutter\bin` vào PATH.
2. Cài [Android Studio](https://developer.android.com/studio), sau đó chạy `flutter doctor --android-licenses`.
3. Chạy `flutter doctor` và xử lý hết các dấu ✗ ở phần Android.

### 2. Tạo project & chạy thử (chưa cần Facebook)
```bash
powershell -ExecutionPolicy Bypass -File .\setup.ps1
```
```bash
flutter run
```
Script tạo các file Android còn thiếu, đặt `minSdk = 23`, tải thư viện và chạy test. Lúc này đã chơi được ở **chế độ khách**. Nút Facebook sẽ báo "chưa cấu hình".

### 3. Bật Đăng nhập Facebook + Bạn bè (Firebase)
**a. Firebase**
1. Tạo project tại <https://console.firebase.google.com>.
2. Cài FlutterFire CLI rồi cấu hình cho Android:
   ```bash
   dart pub global activate flutterfire_cli
   ```
   ```bash
   flutterfire configure --platforms=android
   ```
   Lệnh này tạo `android/app/google-services.json` và thêm plugin Google Services vào Gradle.
3. **Firestore Database**: tạo database, rồi dán nội dung [firestore.rules](firestore.rules) vào tab *Rules* và bấm *Publish*.
4. **Authentication → Sign-in method → Facebook**: bật lên, nhập App ID / App Secret (lấy ở bước b), rồi chép *OAuth redirect URI* để dùng ở bước b.

**b. Facebook**
1. Tạo app tại <https://developers.facebook.com> (loại *Consumer*) và thêm sản phẩm **Facebook Login**.
2. Phần Android: Package name `com.mathjump.math_jump`, Class name `com.mathjump.math_jump.MainActivity`.
3. Key hash của máy debug (mật khẩu `android`, cần có OpenSSL):
   ```bash
   keytool -exportcert -alias androiddebugkey -keystore "%USERPROFILE%\.android\debug.keystore" | openssl sha1 -binary | openssl base64
   ```
4. Ở *Facebook Login → Settings*, dán OAuth redirect URI của Firebase vào *Valid OAuth Redirect URIs*.
5. Điền **App ID** và **Client Token** (Settings → Advanced) vào [android/app/src/main/res/values/strings.xml](android/app/src/main/res/values/strings.xml).

### 4. Build file cài đặt
```bash
flutter build apk --release
```
File APK nằm ở `build/app/outputs/flutter-apk/app-release.apk`. Muốn đưa lên Google Play thì cần ký bằng keystore riêng và thêm key hash release vào Facebook.

## Cấu trúc mã nguồn

```
lib/
  main.dart                    Khởi động, chọn màn Đăng nhập/Trang chủ
  game/question.dart           Sinh phép tính (đảm bảo chỉ 1 đáp án đúng), độ khó theo level
  state/app_state.dart         Trạng thái app, lưu kết quả, đồng bộ khi có mạng
  services/local_store.dart    Lưu dữ liệu trên máy (SharedPreferences)
  services/cloud_service.dart  Facebook login, Firestore: hồ sơ, kỷ lục, kết bạn
  screens/                     login, home, game, result, leaderboard, friends, settings
  widgets/climber_view.dart    Cầu thang + nhân vật nhảy
  l10n/strings.dart            Bản dịch Việt / Anh
firestore.rules                Luật bảo mật Firestore
```
