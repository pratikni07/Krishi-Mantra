part of 'splash_bloc.dart';

@immutable
abstract class SplashState extends Equatable{
  @override
  List<Object> get props => [];
}

final class SplashInitial extends SplashState {}

class Authenticated extends SplashState {
  final String role;

  Authenticated(this.role);

  @override
  List<Object> get props => [role];
}
class Unauthenticated extends SplashState {

  Unauthenticated();

  @override
  List<Object> get props => [];
}
