import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/colors.dart';

class Services extends StatelessWidget {
  final List<ServiceItem> serviceItems = [
    ServiceItem('assets/Images/serviceImg/test1.png', 'Consultation', '/consultation'),
    ServiceItem('assets/Images/serviceImg/test2.png', 'Crop Calendar', '/crop-calendar'),
    ServiceItem('assets/Images/serviceImg/test3.png', 'Companies', '/companies'),
    ServiceItem('assets/Images/serviceImg/test4.png', 'Fertilizers', '/fertilizers'),
    ServiceItem('assets/Images/serviceImg/test5.png', 'Krishi AI', '/krishi-ai'),
    ServiceItem('assets/Images/serviceImg/test6.png', 'Krishi Videos', '/krishi-videos'),
    ServiceItem('assets/Images/serviceImg/test7.png', 'News', '/news'),
    ServiceItem('assets/Images/serviceImg/test8.png', 'Schemes', '/schemes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.green,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: serviceItems.sublist(0, 4).map((item) => 
                Container(
                  width: 85,
                  height: 110,
                  child: _buildServiceItem(context, item),
                )
              ).toList(),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: serviceItems.sublist(4).map((item) => 
                Container(
                  width: 85,
                  height: 110,
                  child: _buildServiceItem(context, item),
                )
              ).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(BuildContext context, ServiceItem item) {
    return GestureDetector(
      onTap: () {
        Get.toNamed(item.route);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(
                color: AppColors.green,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Image.asset(
                item.imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.image,
                      size: 30,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 8),
          Container(
            height: 35,
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServiceItem {
  final String imagePath;
  final String label;
  final String route;

  ServiceItem(this.imagePath, this.label, this.route);
}