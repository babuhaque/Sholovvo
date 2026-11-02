import 'package:flutter/material.dart';
import 'package:sholovvo_app/design/motion/fade_slide_route.dart';
import 'package:sholovvo_app/features/auth/presentation/forgot_password_screen.dart';
import 'package:sholovvo_app/features/auth/presentation/login_screen.dart';
import 'package:sholovvo_app/features/auth/presentation/register_screen.dart';
import 'package:sholovvo_app/features/welcome/presentation/welcome_screen.dart';

/// Named routes for the screens that are pushed **above** the auth gate.
///
/// Welcome, verification and the signed-in home are not here: the gate renders
/// them itself, because they are consequences of the session rather than
/// destinations someone navigates to. Anything in this file is a form the user
/// voluntarily opens and can leave.
abstract final class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
}

abstract final class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.login => FadeSlidePageRoute<void>(
        page: const LoginScreen(),
        settings: settings,
      ),
      AppRoutes.register => FadeSlidePageRoute<void>(
        page: const RegisterScreen(),
        settings: settings,
      ),
      AppRoutes.forgotPassword => FadeSlidePageRoute<void>(
        page: const ForgotPasswordScreen(),
        settings: settings,
      ),
      // Unknown route: land on the welcome screen rather than a splash that no
      // longer knows where to go.
      _ => FadeSlidePageRoute<void>(
        page: const WelcomeScreen(),
        settings: settings,
      ),
    };
  }
}
