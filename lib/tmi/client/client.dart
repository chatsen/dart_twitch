import 'dart:async';

import 'package:dart_twitch/auth/credentials.dart';
import 'package:dart_twitch/dart_twitch.dart';
import 'package:dart_twitch/tmi/connection/connection.dart';
import 'package:dart_twitch/tmi/external/listener.dart';

import 'clientchannels.dart';

class Client {
  List<Listener> listeners = [];
  ClientChannels channels = ClientChannels();

  Credentials credentials;

  late Connection receiver;
  late Connection transmitter;
  late Timer _joinTimer;

  Future<void> _join() async {
    if (!(receiver.state is ConnectionConnected)) return;
    for (var channel in channels.state.where((channel) => channel.state is ChannelDisconnected)) {
      await receiver.send('JOIN ${channel.name}');
      channel.add(ChannelJoin(receiver, transmitter));
    }
  }

  Client(this.credentials) {
    receiver = Connection(this, credentials);
    transmitter = Connection(this, credentials);
    _joinTimer = Timer.periodic(Duration(seconds: 2), (timer) => _join());
  }
}
