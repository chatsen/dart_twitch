import 'package:dart_twitch/dart_twitch.dart';

class SubMessage extends Message {
  final String? prefix;

  SubMessage({
    this.prefix,
    IRCMessage? ircMessage,
    required String body,
    required DateTime time,
    required String id,
    User? user,
    Channel? channel,
  }) : super(
          id: id,
          body: body,
          time: time,
          user: user,
          ircMessage: ircMessage,
          channel: channel,
        );
}
