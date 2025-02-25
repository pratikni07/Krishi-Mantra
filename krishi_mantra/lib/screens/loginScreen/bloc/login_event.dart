part of 'login_bloc.dart';

@immutable
abstract class LoginEvent {}

class LoginSubmitted extends LoginEvent {
  final String email;
  final String password;

  LoginSubmitted(this.email, this.password);
}

class CheckLoginStatus extends LoginEvent {}

class LogoutRequested extends LoginEvent {}
