import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class ListItem extends StatelessWidget {
  final int index;

  const ListItem({
    super.key,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        title: Text(
          'Item ${index + 1}',
          style: TextStyle(
            color: AppColors.textGrey,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
