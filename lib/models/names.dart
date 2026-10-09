import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Chuẩn hóa tên để tìm kiếm: chữ thường, bỏ dấu tiếng Việt, gộp khoảng trắng.
/// "  Nguyễn  Minh Đức " → "nguyen minh duc".
String normalizeName(String s) {
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  final map = <String, String>{
    for (final e in groups.entries)
      for (final ch in e.value.split('')) ch: e.key,
  };
  final lower = s.toLowerCase();
  final out = StringBuffer();
  for (final ch in lower.split('')) {
    out.write(map[ch] ?? ch);
  }
  return out.toString().trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// Mã hóa một chiều (SHA-256) email đã chuẩn hóa. Chỉ lưu mã này lên máy chủ
/// để tìm theo đúng toàn bộ email — không ai đọc ngược ra được email thật.
String emailHash(String email) =>
    sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();

/// Một số từ thô tục (so theo từng từ, giữ nguyên dấu để tránh bắt nhầm tên
/// thật như "Lớn"). Danh sách cơ bản, có thể bổ sung.
const _banned = {
  'địt', 'đụ', 'lồn', 'cặc', 'buồi', 'đéo', 'đĩ', 'dái', 'đm', 'dm', 'vcl', 'vkl',
  'clm', 'cmm', 'đcm', 'dcm', 'fuck', 'fucker', 'shit', 'bitch', 'dick', 'pussy',
  'cunt', 'sex', 'porn', 'nigger', 'nigga', 'asshole',
};

const displayNameMin = 2;
const displayNameMax = 20;

/// Kiểm tra tên hiển thị. Trả về null nếu hợp lệ, hoặc khóa thông báo lỗi.
String? validateDisplayName(String raw) {
  final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.length < displayNameMin) return 'nameTooShort';
  if (name.length > displayNameMax) return 'nameTooLong';
  final words = name.toLowerCase().split(RegExp(r'[^\p{L}\p{N}]+', unicode: true));
  if (words.any(_banned.contains)) return 'nameBad';
  return null;
}

/// Tên hiển thị sau khi gọn khoảng trắng.
String cleanDisplayName(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');
