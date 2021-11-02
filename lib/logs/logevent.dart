class LogEvent {
  late DateTime time;
  final dynamic event;

  LogEvent(this.event) {
    time = DateTime.now();
  }
}
