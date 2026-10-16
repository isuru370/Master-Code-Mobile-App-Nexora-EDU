import 'package:flutter/material.dart';

import '../../core/errors/app_exceptions.dart';
import '../../core/navigation/role_router.dart';
import '../../core/storage/session_storage.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();

    _checkSession();
  }

  Future<void> _checkSession() async {
    // Splash animation runs while we check the session
    final splashDelay = Future.delayed(const Duration(seconds: 2));

    final token = await SessionStorage.getToken();

    // No token -> Sign In
    if (token == null || token.trim().isEmpty) {
      await splashDelay;
      _goToSignIn();
      return;
    }

    // Ask the server who this token belongs to (role / branches may have
    // changed, or the account may be disabled)
    String? signInMessage;
    var mustSignIn = false;

    try {
      await AuthRemoteDataSource().me(); // saves the fresh session
    } on UnauthorizedException {
      // Token expired / deleted -> log in again
      mustSignIn = true;
      signInMessage = 'Your session has expired. Please sign in again.';
    } on ServerException catch (e) {
      if (e.statusCode == 403) {
        // Account / role inactive, no branch, no teacher profile ...
        mustSignIn = true;
        signInMessage = e.message;
      }
      // Other server errors: continue with the saved session
    } on NetworkException {
      // Offline: continue with the saved session
    } catch (e) {
      debugPrint('SPLASH /me ERROR: $e');
    }

    await splashDelay;

    if (!mounted) return;

    if (mustSignIn) {
      await SessionStorage.clear();
      _goToSignIn(message: signInMessage);
      return;
    }

    final user = await SessionStorage.getUser();
    final role = await SessionStorage.getRole();
    final route = RoleRouter.homeRouteFor(role);

    debugPrint('SPLASH USER ROLE: $role');

    if (!mounted) return;

    // Broken saved data or a role the app does not support -> Sign In
    if (user == null || route == null) {
      await SessionStorage.clear();
      _goToSignIn();
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      route,
      arguments: {'token': token, 'user_model': user},
    );
  }

  void _goToSignIn({String? message}) {
    if (!mounted) return;

    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    Navigator.pushReplacementNamed(context, RoleRouter.signIn);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 112, 122, 126),
              Color.fromARGB(255, 161, 172, 177),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 140,
                    child: Image.asset(
                      'assets/logo/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(height: 2),

                  const Text(
                    "MIHISARA HIGHER EDUCATION INSTITUTE",
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    "Towards a bright future",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}