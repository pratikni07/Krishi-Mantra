import 'package:flutter/material.dart';

import '../../../../data/models/company_model.dart';
import '../../../../data/services/language_service.dart';

class CompanyHeader extends StatelessWidget {
  final CompanyModel company;

  const CompanyHeader({Key? key, required this.company}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Colors.grey[50], // Light off-white shade
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    company.logo,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[200],
                        child: Icon(Icons.business, size: 40, color: Colors.grey),
                      );
                    },
                  ),
                ),
                SizedBox(width: 16),
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
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          );
                        }
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 20),
                          SizedBox(width: 4),
                          Text(
                            '${company.rating.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 16,
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
              SizedBox(height: 16),
              FutureBuilder<String?>(
                future: company.getTranslatedDescription(),
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? company.description ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  );
                }
              ),
            ],
          ],
        ),
      ),
    );
  }
}