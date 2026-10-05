import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/app_providers.dart';
import 'features/auth/providers/auth_provider.dart';

class AiQuantApp extends StatelessWidget {
  final AuthProvider authProvider;

  AiQuantApp({super.key, required this.authProvider})
      : _router = AppRouter.createRouter(authProvider);

  final GoRouter _router;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: AppProviders.providers(authProvider),
      child: MaterialApp.router(
        title: 'AI 量化',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkFinanceTheme,
        routerConfig: _router,
      ),
    );
  }
}
