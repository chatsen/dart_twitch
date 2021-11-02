import 'package:dart_twitch/tmi/channel/channel.dart';
import 'package:dart_twitch/tmi/user/user.dart';

import 'basechatentry.dart';

class BanMessage extends BaseChatEntry {
  final User? user;
  final Duration? duration;

  const BanMessage({
    required DateTime time,
    this.user,
    this.duration,
    Channel? channel,
  }) : super(time: time, channel: channel);
}
