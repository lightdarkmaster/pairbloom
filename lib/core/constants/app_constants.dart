import 'package:flutter/material.dart';

class AppConstants {
  static const appName = 'PairBloom';
  static const tagline = 'A little space for two hearts.';
  static const version = '1.0.0';
  static const defaultCurrency = '₱';
  static const currencies = ['₱', r'$', '€', '£', '¥', '₩', '₹'];

  static const relationshipStatuses = [
    'Dating',
    'In a Relationship',
    'Engaged',
    'Married',
    "It's Complicated",
  ];

  static const memoryCategories = [
    'Date Night',
    'Travel',
    'Milestone',
    'Everyday Moment',
    'Celebration',
    'Family & Friends',
    'Other',
  ];

  static const eventTypes = [
    'Birthday',
    'Anniversary',
    'Monthsary',
    'First Date',
    'First Kiss',
    'Special Occasion',
    'Custom',
  ];
}

/// Keys used in the `app_settings` table.
class SettingKeys {
  static const themeMode = 'theme_mode';
  static const accentColor = 'accent_color';
  static const currency = 'currency';
}

class AppPalette {
  static const primary = Color(0xFFF4A6BD);
  static const secondary = Color(0xFFFCE4EC);
  static const accent = Color(0xFFD85B83);
  static const background = Color(0xFFFFF9FA);
  static const darkBackground = Color(0xFF211820);

  static const accentChoices = <Color>[
    Color(0xFFD85B83), // rose (default)
    Color(0xFFE57373), // coral
    Color(0xFFB57EDC), // lavender
    Color(0xFF7E9CDC), // periwinkle
    Color(0xFF4DB6AC), // mint
    Color(0xFFF2A65A), // peach
  ];
}

/// Built-in offline collection of daily love quotes.
class LoveQuotes {
  static const all = <String>[
    'Every ordinary day is better with you in it.',
    'Home is wherever you are.',
    'Love grows in the small moments we choose to share.',
    'With you, even silence feels like a conversation.',
    'We are a team, in every season.',
    'Thank you for being my calm and my adventure.',
    'Two hearts, one little world.',
    'The best part of my day is coming back to you.',
    'Love is choosing each other, again and again.',
    'You make the simple things feel special.',
    'Our story is my favorite one to keep writing.',
    'Hand in hand is my favorite way to walk through life.',
    'Being loved by you feels like sunshine on a slow morning.',
    'Grateful for your laugh, your hugs, and your patience.',
    'Whatever we do, I want to do it with you.',
    'You are my favorite hello and my hardest goodbye.',
    'A good love is quiet, kind, and brave.',
    'Together turns plans into memories.',
    'I fall for you in new little ways every day.',
    'Here is to more mornings, more dances, more us.',
    'Your happiness is one of my favorite things.',
    'Love is the thread that keeps our days together.',
    'We bloom best side by side.',
    'You are the reason ordinary becomes beautiful.',
    'Every chapter with you is my favorite.',
  ];

  static String forDate(DateTime d) {
    final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays;
    return all[dayOfYear % all.length];
  }
}
