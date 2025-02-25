import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatefulWidget {
  final Function(int) onTap;
  final int currentIndex;

  const CustomBottomNavBar({
    Key? key,
    required this.onTap,
    required this.currentIndex,
  }) : super(key: key);

  @override
  State<CustomBottomNavBar> createState() => _CustomBottomNavBarState();
}

class _CustomBottomNavBarState extends State<CustomBottomNavBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: widget.onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFF4CAF50),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, size: 30),  // Increased size
            activeIcon: Icon(Icons.home, size: 30),     // Increased size
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined, size: 30), // Increased size
            activeIcon: Icon(Icons.grid_view, size: 30),    // Increased size
            label: 'Feed',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.volunteer_activism_outlined, size: 30), // Increased size
            activeIcon: Icon(Icons.volunteer_activism, size: 30),    // Increased size
            label: 'Crop Care',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined, size: 30), // Increased size
            activeIcon: Icon(Icons.store, size: 30),    // Increased size
            label: 'Mandi',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 30), // Increased size
            activeIcon: Icon(Icons.person, size: 30),    // Increased size
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
