import 'package:dart_twitch/tmi/channel/channel.dart';
import 'package:dart_twitch/tmi/message/basechatentry.dart';

class NoticeMessage extends BaseChatEntry {
  final String body;

  const NoticeMessage({
    required this.body,
    required DateTime time,
    Channel? channel,
  }) : super(time: time, channel: channel);
}
