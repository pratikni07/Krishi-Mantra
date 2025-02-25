import 'package:flutter/material.dart';
import '../models/company.dart';
import '../data/demo_data.dart';

class CompanyListScreen extends StatefulWidget {
  @override
  _CompanyListScreenState createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fertilizer Companies', 
          style: TextStyle(
            color: Colors.white, 
            fontWeight: FontWeight.bold
          )
        ),
        backgroundColor: Colors.green[700],
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // TODO: Implement search functionality
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // Two companies per row
            childAspectRatio: 0.8, // Adjust this for proper sizing
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: demoCompanies.length,
          itemBuilder: (context, index) {
            final company = demoCompanies[index];
            return CompanyCard(
              company: company,
              onTap: () {
                Navigator.pushNamed(
                  context, 
                  '/company-details', 
                  arguments: company
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class CompanyCard extends StatelessWidget {
  final Company company;
  final VoidCallback onTap;

  const CompanyCard({
    Key? key, 
    required this.company, 
    required this.onTap
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Logo
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green[100]!, width: 3),
                image: DecorationImage(
                  image: NetworkImage(company.logo),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            
            SizedBox(height: 10),
            
            // Company Name
            Text(
              company.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            
            SizedBox(height: 5),
            
            // Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star, 
                  color: Colors.amber, 
                  size: 18
                ),
                SizedBox(width: 4),
                Text(
                  '${company.rating.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}