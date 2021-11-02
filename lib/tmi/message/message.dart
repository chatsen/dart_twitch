import 'package:dart_twitch/irc/irc_message.dart';
import 'package:dart_twitch/tmi/channel/channel.dart';
import 'package:dart_twitch/tmi/user/user.dart';

import 'basechatentry.dart';

class Message extends BaseChatEntry {
  IRCMessage? ircMessage;
  String body;
  User? user;
  String id;

  Message({
    this.ircMessage,
    required this.body,
    required DateTime time,
    required this.id,
    this.user,
    Channel? channel,
  }) : super(time: time, channel: channel);
}
