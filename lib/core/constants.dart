import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // ── Worker ────────────────────────────────────────────────────────────────
  static const String workerUrl =
      'https://taskflow-backend.vishwajeetadkine705.workers.dev';

  // ── Google OAuth scopes ───────────────────────────────────────────────────
  static const List<String> googleScopes = [
    'https://www.googleapis.com/auth/gmail.readonly',
    'https://www.googleapis.com/auth/gmail.send',
    'https://www.googleapis.com/auth/drive.readonly',
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/forms.body',
    'https://www.googleapis.com/auth/presentations',
    'email',
    'profile',
  ];

  // ── Spacing ───────────────────────────────────────────────────────────────
  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 16.0;
  static const double spacingLG = 24.0;
  static const double spacingXL = 32.0;
  static const double spacingXXL = 48.0;

  // ── Border radius ─────────────────────────────────────────────────────────
  static const double radiusSM = 3.0;
  static const double radiusMD = 4.0;
  static const double radiusLG = 8.0;

  // ── Animation durations ───────────────────────────────────────────────────
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animMed = Duration(milliseconds: 250);
  static const Duration animSlow = Duration(milliseconds: 400);
}

class AppColors {
  AppColors._();

  // ── Core ──────────────────────────────────────────────────────────────────
  static const Color foreground = Color(0xFF111111);
  static const Color foregroundMuted = Color(0xFF333333);
  static const Color muted = Color(0xFF666666);
  static const Color mutedLight = Color(0xFF888888);

  // ── Backgrounds ───────────────────────────────────────────────────────────
  static const Color bgBase = Color(0xFFFDFDFD);
  static const Color bgSurface = Color(0xFFFFFFFF);
  static const Color bgSurfaceHover = Color(0xFFF5F5F5);
  static const Color bgSurfaceActive = Color(0xFFEEEEEE);

  // ── Borders ───────────────────────────────────────────────────────────────
  static const Color border = Color(0xFFEEEEEE);
  static const Color borderStrong = Color(0xFFCCCCCC);

  // ── Semantic ──────────────────────────────────────────────────────────────
  static const Color error = Color(0xFFCC2200);
  static const Color errorLight = Color(0xFFFFF3F0);
  static const Color success = Color(0xFF166534);
  static const Color successLight = Color(0xFFF0FFF4);
  static const Color warning = Color(0xFF92400E);
  static const Color warningLight = Color(0xFFFFFBEB);
}

class AppTextStyles {
  AppTextStyles._();

  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.mutedLight,
    letterSpacing: 1.2,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.muted,
    letterSpacing: 0.2,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12,
    color: AppColors.foregroundMuted,
    height: 1.5,
  );
}