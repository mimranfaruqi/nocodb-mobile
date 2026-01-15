import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nocodb/common/directus_settings.dart';
import 'package:nocodb/common/flash_wrapper.dart';
import 'package:nocodb/common/logger.dart';
import 'package:nocodb/directus_sdk/directus.dart';
import 'package:nocodb/features/directus/routes.dart';

class DirectusSignInPage extends HookConsumerWidget {
  const DirectusSignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostController = useTextEditingController();
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isLoading = useState(false);
    final obscurePassword = useState(true);

    Future<void> handleSignIn() async {
      if (hostController.text.isEmpty ||
          emailController.text.isEmpty ||
          passwordController.text.isEmpty) {
        if (context.mounted) {
          notifyError(
            context,
            'Please fill in all fields',
            StackTrace.current,
          );
        }
        return;
      }

      isLoading.value = true;
      try {
        // Initialize Directus client
        initDirectus(hostController.text);

        // Attempt login
        final authResponse = await directus.login(
          emailController.text,
          passwordController.text,
        );

        // Save credentials
        await directusSettings.save(
          host: hostController.text,
          accessToken: authResponse.access_token,
          refreshToken: authResponse.refresh_token,
          email: emailController.text,
        );

        if (context.mounted) {
          const DirectusCollectionsRoute().go(context);
        }
      } catch (e, s) {
        logger.shout('Login failed: $e');
        logger.fine(s.toString());
        if (context.mounted) {
          notifyError(context, e, s);
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.storage,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 24),
                Text(
                  'Directus Mobile',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to your Directus instance',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                TextField(
                  controller: hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host URL',
                    hintText: 'https://your-directus.example.com',
                    prefixIcon: Icon(Icons.cloud),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                  enabled: !isLoading.value,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'user@example.com',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isLoading.value,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword.value
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        obscurePassword.value = !obscurePassword.value;
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: obscurePassword.value,
                  enabled: !isLoading.value,
                  onSubmitted: (_) => handleSignIn(),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading.value ? null : handleSignIn,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading.value
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
