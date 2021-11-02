// ignore_for_file: empty_catches

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dart_twitch/auth/credentials.dart';
import 'package:dart_twitch/dart_twitch.dart';
import 'package:dart_twitch/irc/irc_message.dart';
import 'package:dart_twitch/logs/logevent.dart';
import 'package:dart_twitch/tmi/message/noticemessage.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'connectionevent.dart';
import '../../logs/logscubit.dart';
import 'connectionstate.dart';

class Connection extends Bloc<ConnectionEvent, ConnectionState> {
  Client client;
  WebSocketChannel? _webSocketChannel;
  StreamSubscription? _streamSubscription;
  final LogsCubit logs = LogsCubit();

  Connection(this.client, Credentials credentials) : super(ConnectionDisconnected()) {
    add(ConnectionConnect(credentials));
  }

  @override
  void onEvent(ConnectionEvent event) {
    logs.add(LogEvent(event));
    super.onEvent(event);
  }

  @override
  void onChange(change) {
    logs.add(LogEvent(change));
    super.onChange(change);

    var channels = client.channels.state.where((channel) => channel.state is ChannelStateWithConnection && (channel.state as ChannelStateWithConnection).receiver == this);
    for (var channel in channels) {
      channel.add(ChannelPart());
    }
  }

  Future<void> _destroySocket() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    // await _webSocketChannel?.sink.close();
    _webSocketChannel = null;
  }

  Future<void> _createSocket(Credentials credentials) async {
    await _destroySocket();

    _webSocketChannel = IOWebSocketChannel.connect('wss://irc-ws.chat.twitch.tv:443');
    _streamSubscription = _webSocketChannel!.stream.listen(
      (event) async {
        for (var subevent in event.trim().split('\r\n')) {
          await receive(subevent);
        }
      },
      onError: (e) async {
        await Future.delayed(Duration(seconds: 2));
        add(ConnectionReconnect());
      },
      onDone: () async {
        await Future.delayed(Duration(seconds: 2));
        add(ConnectionReconnect());
      },
      cancelOnError: true,
    );

    await send('CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership');
    if (credentials.token != null) await send('PASS oauth:${credentials.token}');
    await send('NICK ${credentials.login}');
  }

  @override
  Stream<ConnectionState> mapEventToState(ConnectionEvent event) async* {
    if (event is ConnectionConnect) {
      yield ConnectionConnecting(event.credentials);
      await _createSocket(event.credentials);
    } else if (event is ConnectionDisconnect) {
      await _destroySocket();
      yield ConnectionDisconnected();
    } else if (event is ConnectionReconnect && (event.credentials != null || state is ConnectionStateWithCredentials)) {
      var previousCredentials = (state as ConnectionStateWithCredentials).credentials;
      yield ConnectionDisconnected();
      await Future.delayed(Duration(seconds: 1));
      add(ConnectionConnect(event.credentials ?? previousCredentials));
    }
  }

  Future<void> receive(String event) async {
    if (!(state is ConnectionStateWithCredentials)) {
      throw 'Received message without credentials: $event';
    }

    var ircMessage = IRCMessage.fromData(event)!;
    // print('\x1b[32m>: ${ircMessage.command}: \x1b[37m$event\x1b[37m');

    switch (ircMessage.command) {
      case '001':
        emit(ConnectionConnected((state as ConnectionStateWithCredentials).credentials));
        break;
      case 'PING':
        await send('PONG :${ircMessage.parameters[1]}'); // ?? 'tmi.twitch.tv'
        break;
      case 'RECONNECT':
        add(ConnectionReconnect());
        break;
      case 'NOTICE':
        if (ircMessage.parameters[1] == 'Login authentication failed') {
          emit(ConnectionInvalidCredentials((state as ConnectionStateWithCredentials).credentials));
        } else if (ircMessage.tags['msg-id'] == 'msg_channel_suspended') {
          try {
            var channelName = ircMessage.parameters[0];
            var channel = client.channels.state.firstWhere((channel) => channel.name == channelName);
            channel.add(ChannelSuspend());
          } catch (e) {}
        } else {
          try {
            var channelName = ircMessage.parameters[0];
            var channel = client.channels.state.firstWhere((channel) => channel.state is ChannelStateWithConnection && (channel.state as ChannelStateWithConnection).receiver == this && channel.name == channelName);

            channel.messages.add(
              NoticeMessage(
                body: ircMessage.parameters[1],
                time: DateTime.now(),
                channel: channel,
              ),
            );
          } catch (e) {}
        }
        break;
      case 'JOIN':
        try {
          var channelName = ircMessage.parameters[0];
          var channel = client.channels.state.firstWhere((channel) => channel.state is ChannelStateWithConnection && (channel.state as ChannelStateWithConnection).receiver == this && channel.name == channelName);

          var credentials = client.credentials;
          var login = ircMessage.prefix.split('!').first.toLowerCase();

          if (login == credentials.login) channel.add(ChannelConnect());
        } catch (e) {}
        return;
      case 'PART':
        try {
          var channelName = ircMessage.parameters[0];
          var channel = client.channels.state.firstWhere((channel) => channel.state is ChannelStateWithConnection && (channel.state as ChannelStateWithConnection).receiver == this && channel.name == channelName);

          var credentials = client.credentials;
          var login = ircMessage.prefix.split('!').first.toLowerCase();

          if (login == credentials.login) channel.add(ChannelPart());
        } catch (e) {}
        return;
      case 'PRIVMSG':
        try {
          var channelName = ircMessage.parameters[0];
          var channel = client.channels.state.firstWhere((channel) => channel.state is ChannelStateWithConnection && (channel.state as ChannelStateWithConnection).receiver == this && channel.name == channelName);

          var message = Message(
            id: ircMessage.tags['id'],
            body: ircMessage.parameters[1],
            time: DateTime.fromMillisecondsSinceEpoch(int.tryParse(ircMessage.tags['tmi-sent-ts']) ?? 0),
            user: User(
              login: ircMessage.prefix.split('!').first,
              displayName: ircMessage.tags['display-name'],
              id: ircMessage.tags['user-id'],
              color: ircMessage.tags['color'],
            ),
            channel: channel,
          );

          client.listeners.forEach((listener) {
            listener.onMessage(message);
          });
          channel.messages.add(message);
        } catch (e) {}
        return;
      case 'CLEARCHAT':
        try {
          var channelName = ircMessage.parameters[0];
          var channel = client.channels.state.firstWhere((channel) => channel.state is ChannelStateWithConnection && (channel.state as ChannelStateWithConnection).receiver == this && channel.name == channelName);
          var duration = ircMessage.tags['ban-duration'] == null ? null : Duration(seconds: int.tryParse(ircMessage.tags['ban-duration']) ?? 0);

          channel.messages.add(
            BanMessage(
              time: DateTime.now(),
              duration: duration,
              user: ircMessage.tags.containsKey('target-user-id')
                  ? User(
                      login: ircMessage.parameters[1],
                      displayName: ircMessage.parameters[1],
                      id: ircMessage.tags['target-user-id'],
                      // color: ircMessage.tags['color'],
                    )
                  : null,
              channel: channel,
            ),
          );
        } catch (e) {}
        break;
      case 'USERNOTICE':
        try {
          // Raid:
          // @badge-info=;badges=;color=#FF69B4;display-name=TimeClova;emotes=;flags=;id=02139f6a-5cc1-4515-8b0c-aca140a6d6cd;login=timeclova;mod=0;msg-id=raid;msg-param-displayName=TimeClova;msg-param-login=timeclova;msg-param-profileImageURL=https://static-cdn.jtvnw.net/jtv_user_pictures/85e6c1f6-ae9a-4534-a7b4-bcb89a05c1de-profile_image-70x70.png;msg-param-viewerCount=56;room-id=192434734;subscriber=0;system-msg=56\sraiders\sfrom\sTimeClova\shave\sjoined!;tmi-sent-ts=1627730280158;user-id=590368354;user-type= :tmi.twitch.tv USERNOTICE #aimsey

          // Sub with message:
          // @badge-info=subscriber/4;badges=subscriber/3,premium/1;color=#008000;display-name=surbeonxbox;emotes=;flags=;id=707c4e3c-3cb7-422e-9c1c-00bd431338bc;login=surbeonxbox;mod=0;msg-id=resub;msg-param-cumulative-months=4;msg-param-months=0;msg-param-multimonth-duration=0;msg-param-multimonth-tenure=0;msg-param-should-share-streak=1;msg-param-streak-months=4;msg-param-sub-plan-name=Channel\sSubscription\s(xqcow);msg-param-sub-plan=1000;msg-param-was-gifted=false;room-id=71092938;subscriber=1;system-msg=surbeonxbox\ssubscribed\sat\sTier\s1.\sThey've\ssubscribed\sfor\s4\smonths,\scurrently\son\sa\s4\smonth\sstreak!;tmi-sent-ts=1627730157904;user-id=514719264;user-type= :tmi.twitch.tv USERNOTICE #xqcow :YUP

          // Gifted sub:
          // @badge-info=subscriber/13;badges=subscriber/12,glhf-pledge/1;color=#A175B7;display-name=Tharus1337;emotes=;flags=;id=921661da-239e-462d-9a65-5779104816e1;login=tharus1337;mod=0;msg-id=subgift;msg-param-gift-months=1;msg-param-months=32;msg-param-origin-id=b3\s21\sd7\s86\s67\s5c\s59\sdd\sd3\s56\sde\s65\se7\s54\s36\s6e\s17\s76\s82\se0;msg-param-recipient-display-name=truncated_xD;msg-param-recipient-id=91434296;msg-param-recipient-user-name=truncated_xd;msg-param-sender-count=1;msg-param-sub-plan-name=Channel\sSubscription\s(forsenlol);msg-param-sub-plan=1000;room-id=22484632;subscriber=1;system-msg=Tharus1337\sgifted\sa\sTier\s1\ssub\sto\struncated_xD!\sThis\sis\stheir\sfirst\sGift\sSub\sin\sthe\schannel!;tmi-sent-ts=1627730596864;user-id=72864797;user-type= :tmi.twitch.tv USERNOTICE #forsen

          // Sub with message 2:
          // @badge-info=;badges=glhf-pledge/1;color=#FF1493;display-name=splizhh;emotes=;flags=;id=92a97eba-d684-406d-8ca3-21e95c1cc874;login=splizhh;mod=0;msg-id=resub;msg-param-cumulative-months=6;msg-param-months=0;msg-param-multimonth-duration=0;msg-param-multimonth-tenure=0;msg-param-should-share-streak=1;msg-param-streak-months=5;msg-param-sub-plan-name=Channel\sSubscription\s(xqcow);msg-param-sub-plan=Prime;msg-param-was-gifted=false;room-id=71092938;subscriber=1;system-msg=splizhh\ssubscribed\swith\sPrime.\sThey've\ssubscribed\sfor\s6\smonths,\scurrently\son\sa\s5\smonth\sstreak!;tmi-sent-ts=1627742216686;user-id=230654107;user-type= :tmi.twitch.tv USERNOTICE #xqcow :pog

          print('\x1b[32m>: ${ircMessage.command}: \x1b[37m$event\x1b[37m');
          var channelName = ircMessage.parameters[0];
          var channel = client.channels.state.firstWhere((channel) => channel.state is ChannelStateWithConnection && (channel.state as ChannelStateWithConnection).receiver == this && channel.name == channelName);

          channel.messages.add(
            SubMessage(
              id: ircMessage.tags['id'],
              body: ircMessage.parameters.length >= 2 ? ircMessage.parameters[1] : '',
              time: DateTime.fromMillisecondsSinceEpoch(int.tryParse(ircMessage.tags['tmi-sent-ts']) ?? 0),
              user: User(
                login: ircMessage.prefix.split('!').first,
                displayName: ircMessage.tags['display-name'],
                id: ircMessage.tags['user-id'],
                color: ircMessage.tags['color'],
              ),
              prefix: ircMessage.tags['system-msg'].replaceAll('\\s', ' '),
              channel: channel,
            ),
          );
        } catch (e) {}
        // messages
        break;
      case 'CLEARMSG':
        try {
          var channelName = ircMessage.parameters[0];
          var channel = client.channels.state.firstWhere((channel) => channel.state is ChannelStateWithConnection && (channel.state as ChannelStateWithConnection).receiver == this && channel.name == channelName);

          channel.messages.add(
            Message(
              id: ircMessage.tags['id'],
              body: 'A message from ${ircMessage.tags['login']} was deleted: ${ircMessage.parameters[1]}',
              time: DateTime.now(),
              channel: channel,
            ),
          );
        } catch (e) {}
        break;
    }

    logs.add(LogEvent(ircMessage));
  }

  Future<void> send(
    String event, {
    Map<String, dynamic>? keys,
  }) async {
    if (keys != null && keys.isNotEmpty) {
      event = '@${keys.entries.map((entry) => '${entry.key}=${entry.value}').join(';')} $event';
    }

    _webSocketChannel!.sink.add(event);
    var ircMessage = IRCMessage.fromData(event)!;
    ircMessage.output = true;
    // print('\x1b[31m>: ${ircMessage.command}: \x1b[37m$event\x1b[37m');

    logs.add(LogEvent(ircMessage));
  }
}
