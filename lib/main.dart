import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:deliveazone_driver_app/providers/auth_provider.dart';
import 'package:deliveazone_driver_app/providers/parcel_provider.dart';
import 'package:deliveazone_driver_app/providers/location_provider.dart';
import 'package:deliveazone_driver_app/providers/notification_provider.dart';
import 'package:deliveazone_driver_app/screens/splash_screen.dart';
import 'package:deliveazone_driver_app/screens/auth/login_screen.dart';
import 'package:deliveazone_driver_app/screens/main/home_screen.dart';
import 'package:deliveazone_driver_app/screens/main/parcels_screen.dart';
import 'package:deliveazone_driver_app/screens/main/scan_screen.dart';
import 'package:deliveazone_driver_app/screens/main/settings_screen.dart';
import 'package:deliveazone_driver_app/screens/main/history_screen.dart';
import 'package:deliveazone_driver_app/screens/main/profile_screen.dart';
import 'package:deliveazone_driver_app/screens/main/notifications_screen.dart';
import 'package:deliveazone_driver_app/screens/parcel/parcel_detail_screen.dart';
import 'package:deliveazone_driver_app/screens/parcel/delivery_update_screen.dart';
import 'package:deliveazone_driver_app/screens/parcel/map_tracking_screen.dart';
import 'package:deliveazone_driver_app/screens/parcel/pod_screen.dart';
import 'models/parcel.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:deliveazone_driver_app/services/notification_service.dart';

import 'package:deliveazone_driver_app/firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseInitialized = false;
  String? firebaseError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService().initialize(navigatorKey: navigatorKey);
    firebaseInitialized = true;
  } catch (e) {
    firebaseError = e.toString();
    if (kDebugMode) print('Firebase initialization failed: $e');
  }

  runApp(MyApp(firebaseInitialized: firebaseInitialized, firebaseError: firebaseError));
}

class MyApp extends StatelessWidget {
  final bool firebaseInitialized;
  final String? firebaseError;

  const MyApp({
    super.key, 
    this.firebaseInitialized = true,
    this.firebaseError,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ParcelProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'DeliveaZone Driver',
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        theme: ThemeData(
          // ... theme data ...
          useMaterial3: true,
          primaryColor: const Color(0xFF042840),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF042840),
            primary: const Color(0xFF042840),
            secondary: const Color(0xFFAE2E2F),
            error: const Color(0xFFAE2E2F),
            surface: Colors.white,
            background: const Color(0xFFF8FAFC), 
            brightness: Brightness.light,
          ).copyWith(
            tertiary: const Color(0xFFF1F5F9),
          ),
          scaffoldBackgroundColor: const Color(0xFFF8FAFC),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF042840),
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Color(0xFF042840)),
            titleTextStyle: TextStyle(
              color: Color(0xFF042840),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            surfaceTintColor: Colors.transparent,
          ),
          textTheme: const TextTheme(
            displayLarge: TextStyle(
              color: Color(0xFF042840),
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
            ),
            displayMedium: TextStyle(
              color: Color(0xFF042840),
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            displaySmall: TextStyle(
              color: Color(0xFF042840),
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            headlineMedium: TextStyle(
              color: Color(0xFF042840),
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            headlineSmall: TextStyle(
              color: Color(0xFF042840),
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
            titleLarge: TextStyle(
              color: Color(0xFF042840),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
            bodyLarge: TextStyle(
              color: Color(0xFF042840),
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            bodyMedium: TextStyle(
              color: Color(0xFF64748B), 
              fontSize: 14,
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
            labelLarge: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14, 
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8), 
              borderSide: BorderSide.none,
              gapPadding: 0,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)), 
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF042840), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFAE2E2F)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFAE2E2F), width: 1.5),
            ),
            hintStyle: const TextStyle(
              color: Color(0xFF94A3B8), 
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            labelStyle: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            floatingLabelStyle: const TextStyle(
              color: Color(0xFF042840),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)), 
            ),
            margin: EdgeInsets.zero,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFAE2E2F),
              foregroundColor: Colors.white,
              elevation: 0, 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              minimumSize: const Size(double.infinity, 48), 
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF042840),
              side: const BorderSide(color: Color(0xFFCBD5E1)), 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          listTileTheme: const ListTileThemeData(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            dense: true, 
          ),
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xFFF1F5F9),
            selectedColor: const Color(0xFF042840),
            labelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
            secondaryLabelStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide.none,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          dividerTheme: const DividerThemeData(
            color: Color(0xFFE2E8F0),
            thickness: 1,
            space: 1,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFFAE2E2F),
            foregroundColor: Colors.white,
            elevation: 2, 
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: Colors.white,
            selectedItemColor: Color(0xFF042840),
            unselectedItemColor: Color(0xFF94A3B8),
            selectedLabelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            elevation: 0,
            type: BottomNavigationBarType.fixed,
            showUnselectedLabels: true,
            landscapeLayout: BottomNavigationBarLandscapeLayout.spread,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFF1F5F9),
            iconTheme: MaterialStateProperty.resolveWith((states) {
               if (states.contains(MaterialState.selected)) {
                 return const IconThemeData(color: Color(0xFF042840));
               }
               return const IconThemeData(color: Color(0xFF64748B));
            }),
            labelTextStyle: MaterialStateProperty.resolveWith((states) {
              if (states.contains(MaterialState.selected)) {
                return const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF042840),
                );
              }
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              );
            }),
            elevation: 0,
          ),
        ),
        builder: (context, child) {
          // Show error dialog if Firebase initialization failed
          if (!firebaseInitialized) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 60, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Configuration Error',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Firebase failed to initialize. Notifications will not work.\n\nError: ${firebaseError ?? "Unknown error"}\n\nPlease add google-services.json to android/app/',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          // Allow proceeding anyway (with risks)
                          // But we can't easily force rebuild main.dart here
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          return child!;
        },
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => HomeScreen(),
          '/parcels': (context) => const ParcelsScreen(),
          '/scan': (context) => const ScanScreen(),
          '/history': (context) => const HistoryScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/parcel-detail': (context) {
            final parcel = ModalRoute.of(context)!.settings.arguments as Parcel;
            return ParcelDetailScreen(parcel: parcel);
          },
          '/delivery-update': (context) {
            final parcel = ModalRoute.of(context)!.settings.arguments as Parcel;
            return DeliveryUpdateScreen(parcel: parcel);
          },
          '/map-tracking': (context) {
            final parcel = ModalRoute.of(context)!.settings.arguments as Parcel;
            return MapTrackingScreen(parcel: parcel);
          },
          '/pod-screen': (context) {
            final parcel = ModalRoute.of(context)!.settings.arguments as Parcel;
            return PODScreen(parcel: parcel);
          },
        },
      ),
    );
  }
}