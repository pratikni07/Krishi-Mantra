import 'package:flutter/material.dart';
import '../../../../data/models/company_model.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/constants/colors.dart';

class CompanyCard extends StatelessWidget {
  final CompanyModel company;
  final VoidCallback onTap;

  const CompanyCard({
    Key? key,
    required this.company,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final iconErrorSize = ResponsiveUtils.responsive(mobile: 60.0, tablet: 80.0);

    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXL)),
                child: Container(
                  width: double.infinity,
                  color: AppColors.white,
                  padding: RPadding.all(8),
                  child: Image.network(
                    company.logo,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.business, size: iconErrorSize, color: Colors.grey.shade400);
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: RPadding.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    company.name,
                    style: TextStyle(
                      fontSize: AppSizes.fontL,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textGrey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: AppSizes.paddingS),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: ResponsiveUtils.responsive(mobile: 16.0, tablet: 20.0)),
                      SizedBox(width: AppSizes.paddingXS),
                      Expanded(
                        child: Text(
                          company.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: AppSizes.fontS,
                            color: AppColors.textGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}