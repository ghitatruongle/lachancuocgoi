import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_vi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('vi')];

  /// Tên ứng dụng
  ///
  /// In vi, this message translates to:
  /// **'Lá chắn cuộc gọi'**
  String get appTitle;

  /// Tooltip nút cài đặt
  ///
  /// In vi, this message translates to:
  /// **'Cài đặt'**
  String get settings;

  /// Tooltip nút quyền
  ///
  /// In vi, this message translates to:
  /// **'Quyền'**
  String get permissions;

  /// Tooltip nút hướng dẫn
  ///
  /// In vi, this message translates to:
  /// **'Hướng dẫn'**
  String get instructions;

  /// No description provided for @homeSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Phân tích cuộc gọi theo thời gian thực để phát hiện lừa đảo.'**
  String get homeSubtitle;

  /// No description provided for @homeLiveCaptionTip.
  ///
  /// In vi, this message translates to:
  /// **'Khuyên dùng: Bật Phụ đề trực tiếp để bảo vệ tốt nhất'**
  String get homeLiveCaptionTip;

  /// No description provided for @appInfoSemantic.
  ///
  /// In vi, this message translates to:
  /// **'Thông tin ứng dụng Lá chắn cuộc gọi'**
  String get appInfoSemantic;

  /// No description provided for @startMonitoring.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu giám sát'**
  String get startMonitoring;

  /// No description provided for @startMonitoringSemantic.
  ///
  /// In vi, this message translates to:
  /// **'Bắt đầu giám sát cuộc gọi'**
  String get startMonitoringSemantic;

  /// No description provided for @simulationMode.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ giả lập'**
  String get simulationMode;

  /// No description provided for @history.
  ///
  /// In vi, this message translates to:
  /// **'Lịch sử'**
  String get history;

  /// No description provided for @antiScamTips.
  ///
  /// In vi, this message translates to:
  /// **'Mẹo chống lừa đảo'**
  String get antiScamTips;

  /// No description provided for @homePermissionWarning.
  ///
  /// In vi, this message translates to:
  /// **'Một số quyền chưa được cấp — hiệu quả giám sát có thể bị giảm.'**
  String get homePermissionWarning;

  /// No description provided for @demoMode.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ demo'**
  String get demoMode;

  /// No description provided for @demoModeDescription.
  ///
  /// In vi, this message translates to:
  /// **'Nền tảng này không gắn cuộc gọi thật. App chạy kịch bản giả để thử AI. Bản đầy đủ (STT, overlay, call screening) trên Android.'**
  String get demoModeDescription;

  /// No description provided for @demoModeSemantic.
  ///
  /// In vi, this message translates to:
  /// **'Chế độ demo — không gắn cuộc gọi thật'**
  String get demoModeSemantic;

  /// No description provided for @featuresOnThisDevice.
  ///
  /// In vi, this message translates to:
  /// **'Tính năng trên máy này'**
  String get featuresOnThisDevice;

  /// No description provided for @monitoringSubtitle.
  ///
  /// In vi, this message translates to:
  /// **'Phát hiện Lừa đảo & Bạo lực'**
  String get monitoringSubtitle;

  /// No description provided for @monitoringEndCall.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc cuộc gọi'**
  String get monitoringEndCall;

  /// No description provided for @monitoringSavingResult.
  ///
  /// In vi, this message translates to:
  /// **'Đang lưu kết quả...'**
  String get monitoringSavingResult;

  /// No description provided for @monitoringEndCallSemantic.
  ///
  /// In vi, this message translates to:
  /// **'Kết thúc cuộc gọi và lưu kết quả'**
  String get monitoringEndCallSemantic;

  /// No description provided for @monitoringLiveConversation.
  ///
  /// In vi, this message translates to:
  /// **'Cuộc hội thoại trực tiếp'**
  String get monitoringLiveConversation;

  /// No description provided for @monitoringSimulationTranscript.
  ///
  /// In vi, this message translates to:
  /// **'Kịch bản mô phỏng'**
  String get monitoringSimulationTranscript;

  /// No description provided for @monitoringSystemLog.
  ///
  /// In vi, this message translates to:
  /// **'Nhật ký hệ thống'**
  String get monitoringSystemLog;

  /// No description provided for @monitoringSimulationPrefix.
  ///
  /// In vi, this message translates to:
  /// **'Mô phỏng: {title}'**
  String monitoringSimulationPrefix(String title);

  /// No description provided for @monitoringSimulationDefault.
  ///
  /// In vi, this message translates to:
  /// **'Mô phỏng'**
  String get monitoringSimulationDefault;

  /// No description provided for @monitoringRiskSemantic.
  ///
  /// In vi, this message translates to:
  /// **'Mức độ rủi ro cuộc gọi hiện tại: {level}'**
  String monitoringRiskSemantic(String level);

  /// No description provided for @monitoringWaveformSemantic.
  ///
  /// In vi, this message translates to:
  /// **'Biểu đồ sóng âm thanh cuộc gọi trực tiếp'**
  String get monitoringWaveformSemantic;

  /// No description provided for @monitoringModeTarget.
  ///
  /// In vi, this message translates to:
  /// **'Đích: {mode}'**
  String monitoringModeTarget(String mode);

  /// No description provided for @monitoringModeRunning.
  ///
  /// In vi, this message translates to:
  /// **'Chạy: {mode}'**
  String monitoringModeRunning(String mode);

  /// No description provided for @monitoringNetworkOk.
  ///
  /// In vi, this message translates to:
  /// **'Mạng: OK'**
  String get monitoringNetworkOk;

  /// No description provided for @monitoringNetworkError.
  ///
  /// In vi, this message translates to:
  /// **'Mạng: Lỗi'**
  String get monitoringNetworkError;

  /// No description provided for @monitoringSttFatal.
  ///
  /// In vi, this message translates to:
  /// **'Mic/STT lỗi — không nghe được giọng nói. Kiểm tra quyền micro và thử lại.'**
  String get monitoringSttFatal;

  /// No description provided for @monitoringSttFatalWithReason.
  ///
  /// In vi, this message translates to:
  /// **'Mic/STT lỗi — không nghe được giọng nói ({reason}). Kiểm tra quyền micro và thử lại.'**
  String monitoringSttFatalWithReason(String reason);

  /// No description provided for @monitoringNotificationDegraded.
  ///
  /// In vi, this message translates to:
  /// **'Bật thông báo để giám sát ổn định. Android có thể tắt app giữa cuộc gọi nếu thiếu quyền thông báo.'**
  String get monitoringNotificationDegraded;

  /// No description provided for @monitoringWatchdogFailed.
  ///
  /// In vi, this message translates to:
  /// **'Không khôi phục được dịch vụ giám sát nền. Hãy dừng và bắt đầu lại phiên.'**
  String get monitoringWatchdogFailed;

  /// No description provided for @monitoringSttFallbackOffline.
  ///
  /// In vi, this message translates to:
  /// **'STT đã chuyển sang chế độ offline (Vosk)'**
  String get monitoringSttFallbackOffline;

  /// No description provided for @monitoringSttFallbackWithReason.
  ///
  /// In vi, this message translates to:
  /// **'STT offline (Vosk): {reason}'**
  String monitoringSttFallbackWithReason(String reason);

  /// No description provided for @riskLevelLabel.
  ///
  /// In vi, this message translates to:
  /// **'Mức độ rủi ro'**
  String get riskLevelLabel;

  /// No description provided for @warningDismissButton.
  ///
  /// In vi, this message translates to:
  /// **'ĐÃ HIỂU'**
  String get warningDismissButton;

  /// No description provided for @warningRedTitle.
  ///
  /// In vi, this message translates to:
  /// **'NGUY HIỂM'**
  String get warningRedTitle;

  /// No description provided for @warningOrangeTitle.
  ///
  /// In vi, this message translates to:
  /// **'NGUY CƠ'**
  String get warningOrangeTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['vi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'vi':
      return AppLocalizationsVi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
