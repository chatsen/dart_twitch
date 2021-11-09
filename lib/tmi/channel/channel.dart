import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:dart_twitch/auth/credentials.dart';
import 'package:dart_twitch/dart_twitch.dart';
import 'package:dart_twitch/tmi/channel/channelevent.dart';
import 'package:dart_twitch/tmi/channel/channelmessages.dart';
import 'package:dart_twitch/tmi/channel/channelstate.dart';
import 'package:dart_twitch/tmi/message/message.dart';

import 'package:http/http.dart' as http;

class Channel extends Bloc<ChannelEvent, ChannelState> {
  ChannelMessages messages = ChannelMessages();

  String name;
  Credentials? credentials;
  Timer? suspensionTimer;

  Channel({
    required this.name,
    this.credentials,
  }) : super(ChannelDisconnected());

  Future<void> loadHistory() async {
    if (!name.startsWith('#')) return;

    var response = await http.get(Uri.parse('https://api.chatsen.app/v1/history/${name.replaceFirst('#', '')}'));
    var responseBody = jsonDecode(utf8.decode(response.bodyBytes));

    // TODO: Fix this
    // @badge-info=;color=#008000;display-name=Neoslite ;emotes=;flags=;historical=1;id=c7c52217-68d6-47be-808f-b10092cd3ceb;mod=0;rm-received-ts=1635459069901;room-id=97245742;subscriber=0;tmi-sent-ts=1635459069901;turbo=0;user-id=74065425;user-type= :neoslite!neoslite@neoslite.tmi.twitch.tv PRIVMSG #veibae :LUL

    messages.addAll(
      List<Message>.from(
        responseBody['messages'].map((message) => IRCMessage.fromData(message)!).map(
              (ircMessage) => Message(
                id: ircMessage.tags['id'],
                body: ircMessage.parameters[1],
                time: DateTime.fromMillisecondsSinceEpoch(int.tryParse(ircMessage.tags['tmi-sent-ts']) ?? 0),
                user: User(
                  login: ircMessage.prefix.split('!').first,
                  displayName: ircMessage.tags['display-name'],
                  id: ircMessage.tags['user-id'],
                  color: ircMessage.tags['color'],
                ),
              ),
            ),
      ),
    );
  }

  void send(String message, {bool action = false}) {
    if (!(state is ChannelConnected)) return;
    var realState = state as ChannelConnected;
    realState.transmitter.send('PRIVMSG $name :${action ? '/me ' : ''}$message');
  }

  @override
  Stream<ChannelState> mapEventToState(ChannelEvent event) async* {
    suspensionTimer?.cancel();
    suspensionTimer = null;

    if (event is ChannelJoin) {
      yield ChannelConnecting(receiver: event.receiver, transmitter: event.transmitter);
    } else if (event is ChannelPart) {
      yield ChannelDisconnected();
    } else if (event is ChannelConnect && state is ChannelStateWithConnection) {
      var realState = state as ChannelStateWithConnection;
      yield ChannelConnected(receiver: realState.receiver, transmitter: realState.transmitter);
      await loadHistory();
    } else if (event is ChannelBan && state is ChannelStateWithConnection) {
      var realState = state as ChannelStateWithConnection;
      yield ChannelBanned(receiver: realState.receiver, transmitter: realState.transmitter);
    } else if (event is ChannelTimeout && state is ChannelStateWithConnection) {
      var realState = state as ChannelStateWithConnection;
      yield ChannelBanned(receiver: realState.receiver, transmitter: realState.transmitter, unbanTime: DateTime.now().add(event.duration));
      suspensionTimer = Timer(event.duration, () {
        emit(realState);
        // yield ChannelConnected(receiver: realState.receiver, transmitter: realState.transmitter);
      });
    } else if (event is ChannelSuspend && state is ChannelStateWithConnection) {
      var realState = state as ChannelStateWithConnection;
      yield ChannelSuspended(receiver: realState.receiver, transmitter: realState.transmitter);
    }
  }
}
