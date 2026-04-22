import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../viewmodels/auth_notifier.dart';

/// Login screen — email + password form. On success, the router's redirect
/// (listening to auth state) automatically sends the user to their role's
/// home. This screen never calls `context.go(...)` after login itself.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // Form state — the key lets us trigger validation from outside the form.
  final _formKey = GlobalKey<FormState>();

  // Controllers hold the current text of each field. We read them when
  // the user submits, and we're responsible for disposing them.
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  // UI-only state — whether the password is shown or hidden.
  bool _obscurePassword = true;

  @override
  void dispose() {
    // Controllers wrap native resources and MUST be disposed when the
    // widget is torn down. Forget this and you get slow memory leaks.
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Run every field's validator. Returns false if any of them failed.
    if (!_formKey.currentState!.validate()) return;

    // Close the keyboard before we start the async work, so the user
    // sees the loading spinner without the keyboard sitting on top.
    FocusScope.of(context).unfocus();

    final success = await ref.read(authNotifierProvider.notifier).login(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );

    // ALWAYS check `mounted` after await before touching context.
    if (!mounted) return;

    if (!success) {
      // Pull the error message out of the notifier's state and show it.
      final error = ref.read(authNotifierProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
    // On success, router's redirect handles navigation automatically.
    // Nothing else for this screen to do.
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to the notifier's state to rebuild when isLoading changes.
    final auth = ref.watch(authNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              // Prevents the form from stretching edge-to-edge on tablets.
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    // Logo badge
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.sports_basketball,
                        size: 48,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue tracking your team',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 32),

                    // Email field
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),

                    // Password field with show/hide toggle
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Sign in button — disabled while loading
                    FilledButton(
                      onPressed: auth.isLoading ? null : _submit,
                      child: auth.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5),
                            )
                          : const Text('Sign In'),
                    ),
                    const SizedBox(height: 16),

                    // Register link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account?",
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        TextButton(
                          onPressed: auth.isLoading
                              ? null
                              : () => context.push(AppRoutes.register),
                          child: const Text('Create one'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Validators are pure functions: take the input, return `null` if valid
  // or an error message string if not. Flutter's Form renders the string
  // under the field automatically.
  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }
}