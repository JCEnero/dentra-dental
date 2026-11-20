abstract interface class SetupSound {
  Future<void> prepare();

  /// Called synchronously from a tap so browsers can unlock audio.
  void unlock();
  Future<void> play();
  void stop();
  Future<void> dispose();
}
