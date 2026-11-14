# R8 rules for the release build, on top of the Android defaults and
# Flutter's own rules (both added by the Flutter Gradle plugin).
#
# Every plugin this app uses (google_maps_flutter, google_sign_in,
# geolocator, flutter_secure_storage, universal_ble, printing, image_picker,
# file_selector, url_launcher, shared_preferences, wakelock_plus) ships its
# own consumer rules inside its AAR, so nothing extra is needed today. The
# app has no reflection-based JSON (Gson/Moshi) or Firebase on the Java side.
#
# If a release build crashes with ClassNotFoundException or
# NoSuchMethodException, add a -keep rule for that class here and look it up
# in build/app/outputs/mapping/release/mapping.txt.
