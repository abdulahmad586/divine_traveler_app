import 'package:flutter/material.dart';

class AppColors {
  // ── Primary palette ────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF2D5016); // deep forest green
  static const Color primaryMuted  = Color(0xFF4A7C28); // progress, badges
  static const Color gold          = Color(0xFFC9A84C); // completion, highlights

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const Color surface       = Color(0xFFF5F0E8); // warm off-white background
  static const Color cardSurface   = Color(0xFFFFFFFF); // cards on warm background

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1A1A1A); // near-black body text
  static const Color textSecondary = Color(0xFF6B6B6B); // supporting labels

  // ── Border ─────────────────────────────────────────────────────────────────
  static const Color border        = Color(0xFFE0D8CC); // subtle dividers

  // ── Legacy alias — use sparingly while migrating ───────────────────────────
  static const Color primaryColor  = primary;
}
