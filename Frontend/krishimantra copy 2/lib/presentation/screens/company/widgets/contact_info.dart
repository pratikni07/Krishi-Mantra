import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/models/company_model.dart';

class ContactInfo extends StatelessWidget {
  final CompanyModel company;

  const ContactInfo({Key? key, required this.company}) : super(key: key);

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Widget _buildContactTile({
    required IconData icon,
    required String title,
    required String? subtitle,
    VoidCallback? onTap,
    bool isLast = false,
  }) {
    if (subtitle == null) return SizedBox.shrink();
    
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.grey[700], size: 24),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.3,
              ),
            ),
          ),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(height: 1, indent: 20, endIndent: 20, color: Colors.grey[200]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Contact Information',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          Divider(height: 1, color: Colors.grey[200]),
          _buildContactTile(
            icon: Icons.email,
            title: 'Email',
            subtitle: company.email,
            onTap: company.email != null 
                ? () => _launchURL('mailto:${company.email}')
                : null,
          ),
          _buildContactTile(
            icon: Icons.phone,
            title: 'Phone',
            subtitle: company.phone,
            onTap: company.phone != null 
                ? () => _launchURL('tel:${company.phone}')
                : null,
          ),
          _buildContactTile(
            icon: Icons.language,
            title: 'Website',
            subtitle: company.website,
            onTap: company.website != null 
                ? () => _launchURL(company.website!)
                : null,
          ),
          if (company.address != null)
            _buildContactTile(
              icon: Icons.location_on,
              title: 'Address',
              subtitle: '${company.address!.street}\n${company.address!.city}, ${company.address!.state} ${company.address!.zip}',
              isLast: true,
            ),
        ],
      ),
    );
  }
}