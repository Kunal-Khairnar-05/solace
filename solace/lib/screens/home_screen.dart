import 'package:flutter/material.dart';
// Note: Assuming you're using a modern auth solution.
// The sign-out logic would be adapted for Clerk or another provider.
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:solace/screens/tabs/converse_screen.dart';
import 'package:solace/screens/tabs/history_screen.dart';
import 'package:solace/screens/tabs/profile_screen.dart';
import 'package:solace/screens/tabs/reports_screen.dart';
import 'package:solace/screens/tabs/sessions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _widgetOptions = <Widget>[
    const ConverseScreen(),
    const ReportsScreen(),
    const HistoryScreen(),
    const SessionsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _signOut() async {
    // This would be replaced with your auth provider's sign-out method, e.g., Clerk.instance.signOut()
    // await FirebaseAuth.instance.signOut();
    // For demonstration purposes:
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sign-out action triggered.")));
  }

  @override
  Widget build(BuildContext context) {
    // Placeholder for user's name
    const displayName = 'Rohan';

    return Scaffold(
      // The AppBar is removed to give the ConverseScreen a more immersive feel.
      // Each screen can manage its own AppBar if needed.
      // appBar: AppBar(...)
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        // NEW: Setting the type to 'fixed' ensures the background color is always applied.
        type: BottomNavigationBarType.fixed,
        // NEW: A background color that matches the app's dark theme surface.
        backgroundColor: const Color.fromARGB(255, 192, 232, 248),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.mic_none_outlined),
            activeIcon: Icon(Icons.mic),
            label: 'Converse',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.self_improvement_outlined),
          //   activeIcon: Icon(Icons.self_improvement),
          //   label: 'Sessions',
          // ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        // NEW: Explicitly setting the colors for selected and unselected items.
        selectedItemColor: const Color.fromARGB(255, 29, 32, 33), // Calming primary blue
        unselectedItemColor: const Color.fromARGB(255, 104, 104, 104).withOpacity(0.6),
        showUnselectedLabels: false, // Cleaner look
        onTap: _onItemTapped,
      ),
    );
  }
}
