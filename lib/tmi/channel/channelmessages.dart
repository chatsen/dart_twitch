import 'dart:math';

import 'package:bloc/bloc.dart';
import 'package:dart_twitch/tmi/message/basechatentry.dart';
import 'package:dart_twitch/tmi/message/message.dart';

class ChannelMessages extends Cubit<List<BaseChatEntry>> {
  ChannelMessages() : super([]);

  static List<BaseChatEntry> sort(List<BaseChatEntry> messages) {
    messages.sort((a, b) => a.time.compareTo(b.time));
    return messages.sublist(max(messages.length - 1000, 0));
  }

  void add(BaseChatEntry message) {
    if (message is Message && state.whereType<Message>().any((stateMessage) => stateMessage.id == message.id)) return;
    var newState = sort([...state, message]);
    emit(newState);
  }

  void addAll(List<BaseChatEntry> messages) {
    messages.removeWhere((message) => message is Message && state.whereType<Message>().any((stateMessage) => stateMessage.id == message.id));
    var newState = sort([...state, ...messages]);
    emit(newState);
  }
}
