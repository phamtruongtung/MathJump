import 'package:flutter/widgets.dart';

const _vi = <String, String>{
  'appName': 'Math Jump',
  'tagline': 'Nhảy lên cùng những con số!',
  'loginFacebook': 'Đăng nhập bằng Facebook',
  'playAsGuest': 'Chơi ngay (không đăng nhập)',
  'guestNote': 'Chế độ khách chỉ lưu trên máy này và chưa kết bạn được.',
  'loginFailed': 'Đăng nhập thất bại: {msg}',
  'firebaseMissing':
      'Ứng dụng chưa được cấu hình Facebook/Firebase. Bạn vẫn có thể chơi chế độ khách.',
  'guestName': 'Bạn nhỏ',
  'hello': 'Xin chào, {name}!',
  'play': 'CHƠI',
  'leaderboard': 'Xếp hạng',
  'friends': 'Bạn bè',
  'settings': 'Cài đặt',
  'bestRecord': 'Kỷ lục',
  'noRecord': 'Chưa có kỷ lục — chơi ngay nào!',
  'online': 'Trực tuyến',
  'offline': 'Ngoại tuyến',
  'level': 'Level',
  'score': 'Điểm',
  'time': 'Thời gian sống',
  'correct': 'Phép tính đúng',
  'nextLevel': '{cur}/{goal}',
  'levelUp': 'LEVEL {level}! 🚀',
  'timeUp': 'Hết giờ rồi! ⏰',
  'wrong': 'Ôi, sai mất rồi! 😵',
  'paused': 'Tạm dừng',
  'resume': 'Chơi tiếp',
  'quitTitle': 'Thoát ván chơi?',
  'quitBody': 'Kết quả ván này sẽ không được lưu.',
  'quit': 'Thoát',
  'cancel': 'Hủy',
  'newRecord': 'KỶ LỤC MỚI!',
  'newRecordCongrats': 'Chúc mừng! Bạn vừa lập kỷ lục mới 🎉',
  'yourBest': 'Kỷ lục của bạn: {score} điểm',
  'overtook': 'Bạn đã vượt qua {names} 🚀',
  'playAgain': 'Chơi lại',
  'shareFb': 'Khoe lên Facebook',
  'home': 'Trang chủ',
  'pickStatus': 'Chọn lời khoe nhé',
  'statusCopied':
      'Đã sao chép lời khoe — hãy dán vào ô nội dung bài đăng Facebook nhé!',
  'shareFailed': 'Không chia sẻ được: {msg}',
  'st1':
      '🎉 Mình vừa đạt {score} điểm và leo lên Level {level} hạng {rank} trong Math Jump! Giải đúng liền {correct} phép tính trong {time}. Ai dám thách đấu không? 😎 #MathJump',
  'st2':
      '🧠⚡ Cộng trừ nhân chia nhanh như chớp! {correct} phép tính đúng liên tiếp, {score} điểm, Level {level}. Bạn có vượt qua được mình không? 💪 #MathJump',
  'st3':
      '🐸 Nhảy {correct} bậc thang toán học, trụ vững {time}, đạt {score} điểm! Nhỏ mà có võ đấy nhé 😆 Vào Math Jump đua với mình nào! #MathJump',
  'stRecord':
      '🏆 KỶ LỤC MỚI! {score} điểm – Level {level} – hạng {rank} trong Math Jump. Ai phá được kỷ lục này mình khao trà sữa! 🧋 #MathJump',
  'myHistory': 'Của tôi',
  'you': '(bạn)',
  'lastSync': 'Cập nhật lúc {time}',
  'neverSynced': 'Chưa đồng bộ',
  'needLogin': 'Đăng nhập Facebook để kết bạn và đua top cùng bạn bè.',
  'needOnline': 'Cần kết nối mạng để thực hiện.',
  'noFriends': 'Chưa có bạn nào. Hãy gửi mã kết bạn cho bạn bè nhé!',
  'noGames': 'Chưa có ván chơi nào.',
  'myCode': 'Mã kết bạn của bạn',
  'codeCopied': 'Đã sao chép mã',
  'copy': 'Sao chép',
  'shareCode': 'Gửi mã',
  'shareCodeText':
      'Kết bạn với mình trên Math Jump để đua điểm nhé! Mã của mình: {code}',
  'enterCode': 'Nhập mã của bạn bè',
  'add': 'Kết bạn',
  'requests': 'Lời mời kết bạn',
  'accept': 'Đồng ý',
  'decline': 'Từ chối',
  'myFriends': 'Danh sách bạn bè',
  'removeFriendQ': 'Hủy kết bạn với {name}?',
  'remove': 'Hủy kết bạn',
  'fr_sent': 'Đã gửi lời mời kết bạn!',
  'fr_accepted': 'Hai bạn đã là bạn bè! 🎉',
  'fr_notFound': 'Không tìm thấy mã này.',
  'fr_self': 'Đây là mã của chính bạn mà 😄',
  'fr_already': 'Hai bạn đã là bạn bè rồi.',
  'fr_offline': 'Cần kết nối mạng để thực hiện.',
  'fr_error': 'Có lỗi xảy ra, thử lại sau nhé.',
  'language': 'Ngôn ngữ',
  'character': 'Nhân vật',
  'yourName': 'Tên của bạn',
  'save': 'Lưu',
  'saved': 'Đã lưu',
  'logout': 'Đăng xuất',
  'account': 'Tài khoản',
  'guestAccount': 'Đang chơi chế độ khách',
  'fbAccount': 'Đã đăng nhập Facebook',
  'syncNow': 'Đồng bộ ngay',
  'howToPlay': 'Cách chơi',
  'howToPlayBody':
      'Chọn con số hoặc dấu (+ − × ÷) còn thiếu để phép tính đúng trước khi hết giờ. '
          'Mỗi câu đúng, nhân vật nhảy lên một bậc. Trả lời càng nhanh càng được nhiều điểm. '
          'Đủ điểm sẽ lên level: số lớn hơn, thời gian ngắn hơn. Sai hoặc hết giờ là kết thúc!\n\n'
          'Có 6 hạng: Đồng, Bạc, Vàng, Bạch Kim, Kim Cương, Huyền Thoại. Hạng càng cao thì thời gian '
          'trả lời càng ngắn. Đạt đủ level và điểm trong một ván để thăng hạng.',
  'games': 'Số ván: {n}',
  'rank': 'Hạng',
  'rank_0': 'Đồng',
  'rank_1': 'Bạc',
  'rank_2': 'Vàng',
  'rank_3': 'Bạch Kim',
  'rank_4': 'Kim Cương',
  'rank_5': 'Huyền Thoại',
  'chooseRank': 'Chọn hạng chơi',
  'rankTime': '⏱️ {start} giây → {end} giây mỗi câu',
  'rankLocked': '🔒 Mở khóa: đạt Level {level} và {score} điểm ở hạng {rank}',
  'nextRankGoal': 'Lên hạng {rank}: đạt Level {level} và {score} điểm trong một ván',
  'topRank': 'Bạn đang ở hạng cao nhất! 👑',
  'rankUp': 'THĂNG HẠNG {rank}!',
  'promoted': 'Chúc mừng! Bạn đã thăng hạng {rank} 🎉',
  'sound': 'Âm thanh',
  'music': 'Nhạc nền',
  'sfx': 'Hiệu ứng âm thanh',
};

const _en = <String, String>{
  'appName': 'Math Jump',
  'tagline': 'Jump higher with numbers!',
  'loginFacebook': 'Continue with Facebook',
  'playAsGuest': 'Play as guest',
  'guestNote': 'Guest mode saves on this device only and has no friends.',
  'loginFailed': 'Login failed: {msg}',
  'firebaseMissing':
      'Facebook/Firebase is not configured for this app yet. You can still play as a guest.',
  'guestName': 'Player',
  'hello': 'Hi, {name}!',
  'play': 'PLAY',
  'leaderboard': 'Ranking',
  'friends': 'Friends',
  'settings': 'Settings',
  'bestRecord': 'Best',
  'noRecord': 'No record yet — let\'s play!',
  'online': 'Online',
  'offline': 'Offline',
  'level': 'Level',
  'score': 'Score',
  'time': 'Survival time',
  'correct': 'Correct answers',
  'nextLevel': '{cur}/{goal}',
  'levelUp': 'LEVEL {level}! 🚀',
  'timeUp': 'Time\'s up! ⏰',
  'wrong': 'Oops, wrong answer! 😵',
  'paused': 'Paused',
  'resume': 'Resume',
  'quitTitle': 'Quit this game?',
  'quitBody': 'This game will not be saved.',
  'quit': 'Quit',
  'cancel': 'Cancel',
  'newRecord': 'NEW RECORD!',
  'newRecordCongrats': 'Congratulations! You set a new record 🎉',
  'yourBest': 'Your best: {score} points',
  'overtook': 'You overtook {names} 🚀',
  'playAgain': 'Play again',
  'shareFb': 'Share on Facebook',
  'home': 'Home',
  'pickStatus': 'Pick a caption',
  'statusCopied': 'Caption copied — paste it into your Facebook post!',
  'shareFailed': 'Could not share: {msg}',
  'st1':
      '🎉 I just scored {score} points and reached Level {level} in {rank} rank in Math Jump! {correct} correct answers in a row in {time}. Who dares to challenge me? 😎 #MathJump',
  'st2':
      '🧠⚡ Lightning-fast math! {correct} correct in a row, {score} points, Level {level}. Can you beat me? 💪 #MathJump',
  'st3':
      '🐸 Jumped {correct} math steps and survived {time} for {score} points! Small but mighty 😆 Come race me on Math Jump! #MathJump',
  'stRecord':
      '🏆 NEW RECORD! {score} points – Level {level} – {rank} rank in Math Jump. Beat it and the bubble tea is on me! 🧋 #MathJump',
  'myHistory': 'My games',
  'you': '(you)',
  'lastSync': 'Updated {time}',
  'neverSynced': 'Not synced yet',
  'needLogin': 'Log in with Facebook to add friends and compete together.',
  'needOnline': 'An internet connection is needed.',
  'noFriends': 'No friends yet. Share your friend code!',
  'noGames': 'No games yet.',
  'myCode': 'Your friend code',
  'codeCopied': 'Code copied',
  'copy': 'Copy',
  'shareCode': 'Share code',
  'shareCodeText': 'Add me on Math Jump and let\'s race! My code: {code}',
  'enterCode': 'Enter a friend\'s code',
  'add': 'Add',
  'requests': 'Friend requests',
  'accept': 'Accept',
  'decline': 'Decline',
  'myFriends': 'My friends',
  'removeFriendQ': 'Remove {name} from friends?',
  'remove': 'Remove',
  'fr_sent': 'Friend request sent!',
  'fr_accepted': 'You are now friends! 🎉',
  'fr_notFound': 'Code not found.',
  'fr_self': 'That\'s your own code 😄',
  'fr_already': 'You are already friends.',
  'fr_offline': 'An internet connection is needed.',
  'fr_error': 'Something went wrong, please try again later.',
  'language': 'Language',
  'character': 'Character',
  'yourName': 'Your name',
  'save': 'Save',
  'saved': 'Saved',
  'logout': 'Log out',
  'account': 'Account',
  'guestAccount': 'Playing as guest',
  'fbAccount': 'Logged in with Facebook',
  'syncNow': 'Sync now',
  'howToPlay': 'How to play',
  'howToPlayBody':
      'Pick the missing number or sign (+ − × ÷) to complete the equation before time runs out. '
          'Each correct answer makes your character jump one step. Faster answers earn more points. '
          'Collect enough points to level up: bigger numbers, less time. A wrong answer or timeout ends the game!\n\n'
          'There are 6 ranks: Bronze, Silver, Gold, Platinum, Diamond and Legend. Higher ranks give less time '
          'per question. Reach the required level and score in one game to rank up.',
  'games': 'Games: {n}',
  'rank': 'Rank',
  'rank_0': 'Bronze',
  'rank_1': 'Silver',
  'rank_2': 'Gold',
  'rank_3': 'Platinum',
  'rank_4': 'Diamond',
  'rank_5': 'Legend',
  'chooseRank': 'Choose your rank',
  'rankTime': '⏱️ {start}s → {end}s per question',
  'rankLocked': '🔒 Unlock: reach Level {level} with {score} points in {rank}',
  'nextRankGoal': 'Rank up to {rank}: reach Level {level} with {score} points in one game',
  'topRank': 'You are at the top rank! 👑',
  'rankUp': 'RANK UP: {rank}!',
  'promoted': 'Congratulations! You reached {rank} 🎉',
  'sound': 'Sound',
  'music': 'Background music',
  'sfx': 'Sound effects',
};

String trLang(String lang, String key, [Map<String, Object?> args = const {}]) {
  var s = (lang == 'vi' ? _vi : _en)[key] ?? _en[key] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

extension Tr on BuildContext {
  String get lang => Localizations.localeOf(this).languageCode;
  String tr(String key, [Map<String, Object?> args = const {}]) =>
      trLang(lang, key, args);
}

String fmtDuration(int ms, String lang) {
  final totalSec = ms ~/ 1000;
  final m = totalSec ~/ 60;
  final s = totalSec % 60;
  if (m == 0) {
    final sec = (ms / 1000).toStringAsFixed(1);
    return lang == 'vi' ? '$sec giây' : '${sec}s';
  }
  return lang == 'vi' ? '$m phút $s giây' : '${m}m ${s}s';
}

String fmtDateTime(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
