import 'package:dart_twitch/auth/credentials.dart';
import 'package:equatable/equatable.dart';

abstract class ConnectionState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ConnectionDisconnected extends ConnectionState {}

abstract class ConnectionStateWithCredentials extends ConnectionState {
  final Credentials credentials;

  ConnectionStateWithCredentials(this.credentials);

  @override
  List<Object?> get props => [credentials, ...super.props];
}

class ConnectionConnecting extends ConnectionStateWithCredentials {
  ConnectionConnecting(Credentials credentials) : super(credentials);
}

class ConnectionConnected extends ConnectionStateWithCredentials {
  ConnectionConnected(Credentials credentials) : super(credentials);
}

class ConnectionReconnecting extends ConnectionStateWithCredentials {
  ConnectionReconnecting(Credentials credentials) : super(credentials);
}

class ConnectionBanned extends ConnectionStateWithCredentials {
  ConnectionBanned(Credentials credentials) : super(credentials);
}

class ConnectionInvalidCredentials extends ConnectionStateWithCredentials {
  ConnectionInvalidCredentials(Credentials credentials) : super(credentials);
}
