import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'providers/attendance_provider.dart';
import 'providers/children_provider.dart';
import 'providers/points_provider.dart';
import 'helpers/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChildrenProvider()),
        ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ChangeNotifierProvider(create: (_) => PointsProvider()),
      ],
      child: const LittleLambs(),
    ),
  );
}

class LittleLambs extends StatelessWidget {
  const LittleLambs({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Little Lambs',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.light,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 25.0),
            textStyle: const TextStyle(fontSize: 18),
          ),
        ),
      ),
          home: const HomeScreen(),
        );
      }
    }
  