import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// your goals imports
import 'features/auth/sign_in_page.dart';
import 'data/goals_repository.dart';
import 'data/goal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GoalsApp());
}

class GoalsApp extends StatelessWidget {
  const GoalsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Tutor Dashboard',
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final user = snap.data;
          if (user == null) return const SignInPage(); // not logged in
          return const GoalsHome(); // logged in
        },
      ),
    );
  }
}

class GoalsHome extends StatelessWidget {
  const GoalsHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<List<Goal>>(
        stream: GoalsRepository().streamRoots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final roots = snapshot.data ?? [];
          if (roots.isEmpty) return const Center(child: Text('No goals yet.'));
          return ListView.builder(
            itemCount: roots.length,
            itemBuilder:
                (_, i) => ListTile(
                  title: Text(roots[i].title),
                  subtitle: Text('order=${roots[i].order}'),
                ),
          );
        },
      ),
    );
  }
}
