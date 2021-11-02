import 'package:bloc/bloc.dart';
import 'package:dart_twitch/dart_twitch.dart';
import 'package:dart_twitch/tmi/channel/channel.dart';
import 'package:dart_twitch/tmi/external/listener.dart';

class ClientChannels extends Cubit<List<Channel>> {
  ClientChannels() : super([]);

  void join(String channelName) {
    emit([
      ...state,
      Channel(name: channelName),
    ]);
  }

  void part(Channel channel) {
    if (channel.state is ChannelStateWithConnection) {
      (channel.state as ChannelStateWithConnection).receiver.send('PART ${channel.name}');
    }

    emit([
      ...state.where((element) => element != channel),
      // Channel(name: channelName),
    ]);
  }

  void joinAll(List<String> channelNames) {
    emit([
      ...state,
      for (var channelName in channelNames) Channel(name: channelName),
    ]);
  }
}
