import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/home/home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/auth/profile_edit_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_room_screen.dart';
import 'screens/home/nearby_users_screen.dart';
import 'services/auth_service.dart';
import 'screens/chat/image_view_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    print('Flutter binding initialized');

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized');

    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
    );
    print('Firebase App Check activated');

    // Initialize Mobile Ads SDK with detailed error handling
    try {
      await MobileAds.instance.initialize();
      print('Mobile Ads SDK initialized successfully');

      // Set test device IDs for both Android and iOS
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          testDeviceIds: [
            '2077ef9a63d2b398840261c8221a0c9b', // Android test device
            'GADSimulatorID', // iOS simulator
          ],
        ),
      );
      print('Ad test device configuration updated');
    } catch (adError) {
      print('Failed to initialize ads: $adError');
    }

    runApp(const MyApp());
  } catch (e) {
    print('Critical error in main: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MBTI 매칭',
        theme: ThemeData(
          primaryColor: const Color(0xFFE0DBEF),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE0DBEF),
          ),
          useMaterial3: true,
          fontFamily: 'HakgyoansimDungeunmiso',
          appBarTheme: const AppBarTheme(
            titleTextStyle: TextStyle(
              fontFamily: 'HakgyoansimDungeunmiso',
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontFamily: 'HakgyoansimDungeunmiso',
              fontWeight: FontWeight.w700,
              fontSize: 24,
            ),
            headlineMedium: TextStyle(
              fontFamily: 'HakgyoansimDungeunmiso',
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
            headlineSmall: TextStyle(
              fontFamily: 'HakgyoansimDungeunmiso',
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
            bodyLarge: TextStyle(
              fontFamily: 'HakgyoansimDungeunmiso',
              fontWeight: FontWeight.w400,
              fontSize: 16,
            ),
            bodyMedium: TextStyle(
              fontFamily: 'HakgyoansimDungeunmiso',
              fontWeight: FontWeight.w400,
              fontSize: 14,
            ),
            bodySmall: TextStyle(
              fontFamily: 'HakgyoansimDungeunmiso',
              fontWeight: FontWeight.w400,
              fontSize: 12,
            ),
          ),
        ),
        initialRoute: '/',
        onGenerateRoute: (settings) {
          if (settings.name == '/chat-room') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => ChatRoomScreen(
                chatId: args['chatId'],
                otherUser: args['otherUser'],
              ),
            );
          }
          return null;
        },
        routes: {
          '/': (context) => const AuthWrapper(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/profile-setup': (context) => const ProfileSetupScreen(),
          '/profile-edit': (context) => const ProfileEditScreen(),
          '/home': (context) => const HomeScreen(),
          '/nearby': (context) => const NearbyUsersScreen(),
          '/chat-list': (context) => const ChatListScreen(),
          '/image-view': (context) => _buildImageViewScreen(context),
        },
      ),
    );
  }

  Widget _buildImageViewScreen(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return ImageViewScreen(imageUrl: args['imageUrl']);
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
