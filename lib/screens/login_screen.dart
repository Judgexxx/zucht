import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../brand.dart';
import '../state/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _url;
  late final TextEditingController _user;
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _url = TextEditingController(text: state.storage.serverUrl);
    _user = TextEditingController(text: state.storage.userName);
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await context.read<AppState>().login(_url.text, _user.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: brandAppBar(title: const Text('Vogelzucht')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const BrandHeader(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
            const SizedBox(height: 12),
            Text(
              'Anmelden',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Mit dem Benutzerkonto deiner Webseite. Die App zeigt und ändert genau die Daten, die du auch im Browser siehst.',
              textAlign: TextAlign.center,
            ),
            if (state.sessionExpired) ...[
              const SizedBox(height: 12),
              const Text(
                'Die Anmeldung ist abgelaufen. Nicht übertragene Änderungen bleiben gespeichert.',
                style: TextStyle(color: Colors.orange),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Adresse der Webseite',
                hintText: 'https://meine-seite.de',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _user,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Benutzername',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: _hide,
              onSubmitted: (_) => _busy ? null : _login(),
              decoration: InputDecoration(
                labelText: 'Passwort',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _login,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Anmelden'),
            ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
