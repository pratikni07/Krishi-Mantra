import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../data/services/UserService.dart';

class AppHeader extends StatefulWidget {
  const AppHeader({Key? key}) : super(key: key);

  @override
  _AppHeaderState createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  String username = "User"; // Default value

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    String? fetchedUsername = await UserService().getFirstName();
    if (fetchedUsername != null) {
      setState(() {
        username = fetchedUsername;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(
              Icons.waving_hand,
              color: Color.fromARGB(255, 254, 229, 3),
              size: 28,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hello',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Welcome, $username',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            Icon(Icons.message_outlined, color: AppColors.white, size: 28),
            SizedBox(width: 19),
            Icon(Icons.notifications_outlined,
                color: AppColors.white, size: 28),
          ],
        ),
      ],
    );
  }
}
