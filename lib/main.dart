import 'package:campus_map/screen/AdminLogin.dart';
import 'package:campus_map/screen/AdminPanelScreen.dart';
import 'package:campus_map/screen/homeScreen.dart';
import 'package:campus_map/screen/locationHistoryScreen.dart';
import 'package:campus_map/screen/locationScreen.dart';
import 'package:campus_map/services/LocationProvider.dart';
import 'package:campus_map/utl/navBar.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options:  FirebaseOptions(
      appId: '1:537416884864:android:4268e93aba08685f8abc65',
      apiKey: 'AIzaSyBP3BM2MzgRjtXIS-STTuNX0C7-rg21y3c',
      messagingSenderId: '537416884864',
      projectId: 'campus-map-e21f1',
      storageBucket: 'campus-map-e21f1.appspot.com',
    )
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LocationProvider(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          fontFamily: 'Roboto',
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.grey.shade100,
        ),
        initialRoute: '/welcome',
        routes: {
          '/welcome': (context) => WelcomeScreen(),
          '/home': (context) => HomeScreen(),
          '/gLocation': (context) => GoogleLocationScreen(),
          '/location': (context) => LocationScreen(
            searchQuery: ModalRoute.of(context)?.settings.arguments is Map
                ? (ModalRoute.of(context)?.settings.arguments as Map)['searchQuery']
                : null,
            destination: ModalRoute.of(context)?.settings.arguments is Map
                ? (ModalRoute.of(context)?.settings.arguments as Map)['destination']
                : null,
          ),
          '/admin': (context) => AdminPanelScreen(),
          '/locationHistory': (context) => LocationHistoryScreen(),
          '/navBar': (context) => NavBar(),
          '/login': (context) => LoginScreen(),
        },
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.greenAccent.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/images/world_map.json', fit: BoxFit.contain),
            const SizedBox(height: 30),
            Text(
              'Welcome to',
              style: TextStyle(
                fontSize: 24,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'FPE North Campus\nNavigation System',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 40),
            _buildButton(
              context,
              text: 'Explore',
              icon: Icons.explore,
              onPressed: () {
                Navigator.pushReplacementNamed(
                  context,
                  '/navBar',
                );
              },
            ),
            const SizedBox(height: 20),
            _buildButton(
              context,
              text: 'Admin Panel',
              icon: Icons.admin_panel_settings,
              fontSize: 14,
              onPressed: () {
                Navigator.pushReplacementNamed(
                  context,
                  '/admin',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    double fontSize = 18,
  }) {
    return SizedBox(
      width: 180,
      height: 50,
      child: ElevatedButton(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.all(Colors.white),
          foregroundColor: WidgetStateProperty.all(Colors.black87),
          elevation: WidgetStateProperty.all(6),
          shadowColor: WidgetStateProperty.all(Colors.black54),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(text, style: TextStyle(fontSize: fontSize)),
            const SizedBox(width: 10),
            Icon(icon, size: 20),
          ],
        ),
      ),
    );
  }
}
