import 'package:dart_twitch/dart_twitch.dart';

abstract class BaseChatEntry {
  final DateTime time;
  final Channel? channel;

  const BaseChatEntry({
    required this.time,
    this.channel,
  });
}
