import 'package:flutter/material.dart';

abstract class AppRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xxl = 24.0;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
}
