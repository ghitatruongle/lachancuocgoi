library pii_regex;

// ignore_for_file: library_prefixes
// ignore_for_file: public_member_api_docs

const String vietnameseCaps =
    'A-ZĐÀÁẢÃẠÂẤẦẨẪẬĂẮẰẲẴẶÈÉẺẼẸÊẾỀỂỄỆÌÍỈĨỊÒÓỎÕỌÔỐỒỔỖỘƠỚỜỞỠỢÙÚỦŨỤƯỨỪỬỮỰỲÝỶỸỴ';
const String vietnameseLowers =
    'a-zđàáảãạâấẩẫậăắằẳẵặéèẻẽẹêếềểễệíìỉĩịóòỏõọôốồổỗộơớờởỡợúùủũụưứừửữựýỳỷỹỵ';

final List<String> roleKeywords = <String>[
  'công an',
  'cong an',
  'kiểm sát',
  'kiem sat',
  'toà án',
  'toa an',
  'ngân hàng',
  'ngan hang',
  'bưu điện',
  'buu dien',
  'nhân viên',
  'nhan vien',
  'hỗ trợ',
  'ho tro',
  'đại úy',
  'dai uy',
  'thiếu tá',
  'thieu ta',
  'trung tá',
  'trung ta',
  'thượng tá',
  'thuong ta',
  'tổng đài',
  'tong dai',
  'chăm sóc khách hàng',
  'cham soc khach hang',
];

final RegExp otpRegex = RegExp(
  r'\b(?:mã|ma)\s*(?:otp|xác minh|xac minh|bảo mật|bao mat|kích hoạt|kich hoat)\b(?:[^\d\n]{0,20})((?:\d[\s.-]?){3,7}\d)',
  caseSensitive: false,
);

final RegExp bankAccountRegex = RegExp(
  r'\b(?:số tài khoản|so tai khoan|số tk|so tk|stk|tài khoản|tai khoan)\b(?:[^\d\n]{0,20})((?:\d[\s.-]?){5,17}\d)',
  caseSensitive: false,
);

final RegExp nationalIdRegex = RegExp(
  r'\b(?:cccd|cmnd|căn cước|can cuoc|chứng minh nhân dân|chung minh nhan dan)\b(?:[^\d\n]{0,20})((?:\d[\s.-]?){8,11}\d)',
  caseSensitive: false,
);

final RegExp cardNumberRegex = RegExp(
  r'\b(?:số thẻ|so the|thẻ ngân hàng|the ngan hang|thẻ tín dụng|the tin dung)(?:\b|\s+)(?:[^\d\n]{0,20})((?:\d[\s-]?){11,18}\d)',
  caseSensitive: false,
);

final RegExp emailRegex = RegExp(
  r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
  caseSensitive: false,
);

final RegExp socialMediaRegex = RegExp(
  r'\b(?:zalo|facebook|telegram|tele|fb|ig|instagram|tiktok)\s*(?::|là|la|của tôi là)?\s*([@a-zA-Z0-9_.-]+)\b',
  caseSensitive: false,
);

final RegExp urlRegex = RegExp(
  r'\b(?:https?:\/\/)?(?:www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b(?:[-a-zA-Z0-9()@:%_\+.~#?&//=]*)',
  caseSensitive: false,
);

final RegExp dobRegex = RegExp(
  r'\b(?:sinh ngày|sinh nam|ngày sinh|ngay sinh|sn)?\s*((?:0?[1-9]|[12][0-9]|3[01])[-/\.](?:0?[1-9]|1[012])[-/\.](?:19|20)\d\d)\b',
  caseSensitive: false,
);

final RegExp partialPiiRegex = RegExp(
  r'\b(?:bắt đầu bằng|bat dau bang|đuôi là|duoi la|kết thúc bằng|ket thuc bang|số cuối là|so cuoi la)\s+([a-zA-Z0-9]{3,})',
  caseSensitive: false,
);

final RegExp phoneRegex = RegExp(r'(?:\+84|84|0)(?:[\s.-]?\d){8,10}\b');

final RegExp personNameRegex = RegExp(
  r'\b(?:tôi tên là|toi ten la|em tên là|em ten la|anh tên là|anh ten la|chị tên là|chi ten la|cháu tên là|chau ten la|tên tôi là|ten toi la|tên em là|ten em la|người nhận là|nguoi nhan la|tôi là|toi la|em là|em la|anh là|anh la|chị là|chi la|cháu là|chau la)\s+([a-zđà-ỹ]{2,}(?:\s+[a-zđà-ỹ]+){0,4})',
  caseSensitive: false,
);

final RegExp genericNameRegex = RegExp(
  '(?<![$vietnameseCaps$vietnameseLowers])([$vietnameseCaps][$vietnameseLowers]+(?:\\s+[$vietnameseCaps][$vietnameseLowers]*){1,4})(?![$vietnameseCaps$vietnameseLowers])',
);

final RegExp addressRegex = RegExp(
  r'\b(?:địa chỉ|dia chi|nhà ở|nha o|gửi về|gui ve|giao tới|giao toi)\b(?:\s*(?:là|la|:))?\s+([^,.!?;\n]{6,80})',
  caseSensitive: false,
);

final RegExp compactPhoneRegex = RegExp(
  r'\b(?:số điện thoại|so dien thoai|sdt|điện thoại|dien thoai)\s+((?:\+84|84|0)(?:[\s.-]?\d){8,10})\b',
  caseSensitive: false,
);

final RegExp digitCleaner = RegExp(r'\D');

bool isValidPersonName(String candidate) {
  final normalized = normalizeVietnamese(candidate);
  final wordCount = normalized
      .split(' ')
      .where((part) => part.isNotEmpty)
      .length;
  return normalized.length >= 5 &&
      wordCount >= 2 &&
      wordCount <= 5 &&
      roleKeywords.every((keyword) => !normalized.contains(keyword));
}

bool isValidPhoneNumber(String candidate) {
  final digits = candidate.replaceAll(digitCleaner, '');
  return digits.length >= 9 && digits.length <= 11;
}

String normalizeVietnamese(String input) {
  return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
