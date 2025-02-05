import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/chat/chat_room_screen.dart';

class AppRoutes {
  static final Map<String, WidgetBuilder> routes = {
    '/': (context) => const AuthWrapper(),
    '/login': (context) => const LoginScreen(),
    '/register': (context) => const RegisterScreen(),
    '/profile-setup': (context) => const ProfileSetupScreen(),
    '/home': (context) => const HomeScreen(),
    '/chat-list': (context) => const ChatListScreen(),
  };

  // 동적 라우트 (채팅방과 같이 파라미터가 필요한 경우)
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/chat-room':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            chatId: args['chatId'],
            otherUser: args['otherUser'],
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}

// 인증 상태를 확인하는 Wrapper 위젯
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                final bool profileCompleted = userData['profileCompleted'] ?? false;

                if (profileCompleted) {
                  return const HomeScreen();
                } else {
                  return const ProfileSetupScreen();
                }
              }
              return const LoginScreen();
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}