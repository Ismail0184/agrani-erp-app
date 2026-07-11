class AppConfig {
  AppConfig._();

  static const String appName = 'Agrani ERP';
  static const String apiBaseUrl = 'https://agrani-erp.com/api/mobile/index.php';
  static const String defaultUserPhotoUrl =
      'https://agrani-erp.com/assets/images/staff/staff/user_1_1780557584_5040.jpeg';
  static const Duration apiTimeout = Duration(seconds: 45);
}
