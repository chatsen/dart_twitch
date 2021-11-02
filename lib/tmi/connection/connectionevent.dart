import 'package:dart_twitch/auth/credentials.dart';
import 'package:equatable/equatable.dart';

class ConnectionEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class ConnectionConnect extends ConnectionEvent {
  final Credentials credentials;

  ConnectionConnect(this.credentials);

  @override
  List<Object?> get props => [credentials, ...super.props];
}

class ConnectionDisconnect extends ConnectionEvent {}

class ConnectionReconnect extends ConnectionEvent {
  final Credentials? credentials;

  ConnectionReconnect({
    this.credentials,
  });

  @override
  List<Object?> get props => [credentials, ...super.props];
}
