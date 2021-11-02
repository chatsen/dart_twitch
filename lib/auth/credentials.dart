import 'package:dart_twitch/consts.dart';

class Credentials {
  String login;
  String? token;
  String clientId;
  String? id;

  Credentials({
    this.login = kDefaultUsername,
    this.token,
    this.clientId = kDefaultClientId,
    this.id,
  });
}
