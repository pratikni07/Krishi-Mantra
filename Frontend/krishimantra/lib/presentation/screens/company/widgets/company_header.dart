import 'package:flutter/material.dart';

import '../../../../data/models/company_model.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/constants/colors.dart';

class CompanyHeader extends StatelessWidget {
  final CompanyModel company;

  const CompanyHeader({Key? key, required this.company}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final logoSize = ResponsiveUtils.responsive(mobile: 80.0, tablet: 100.0);
    final errorIconSize = ResponsiveUtils.responsive(mobile: 40.0, tablet: 50.0);

    return Card(
      elevation: 2,
      color: AppColors.scaffoldBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusL)),
      child: Padding(
        padding: RPadding.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  child: Image.network(
                    company.logo,
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: logoSize,
                        height: logoSize,
                        color: Colors.grey[200],
                        child: Icon(Icons.business,
                            size: errorIconSize, color: Colors.grey),
                      );
                    },
                  ),
                ),
                SizedBox(width: AppSizes.paddingL),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FutureBuilder<String>(
                          future: company.getTranslatedName(),
                          builder: (context, snapshot) {
                            return Text(
                              snapshot.data ?? company.name,
                              style: TextStyle(
                                fontSize: AppSizes.fontTitle,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            );
                          }),
                      SizedBox(height: AppSizes.paddingXS),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: AppSizes.iconS),
                          SizedBox(width: AppSizes.paddingXS),
                          Text(
                            company.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: AppSizes.fontL,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (company.description != null) ...[
              SizedBox(height: AppSizes.paddingL),
              FutureBuilder<String?>(
                  future: company.getTranslatedDescription(),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.data ?? company.description ?? '',
                      style: TextStyle(fontSize: AppSizes.fontM, color: AppColors.textGrey),
                    );
                  }),
            ],
          ],
        ),
      ),
    );
  }
}
