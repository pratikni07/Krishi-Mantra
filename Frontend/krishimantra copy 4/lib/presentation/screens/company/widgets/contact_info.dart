import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/models/company_model.dart';
import '../../../../data/services/language_service.dart';

class ContactInfo extends StatefulWidget {
  final CompanyModel company;

  const ContactInfo({Key? key, required this.company}) : super(key: key);

  @override
  State<ContactInfo> createState() => _ContactInfoState();
}

class _ContactInfoState extends State<ContactInfo> {
  String contactInfoText = "Contact Information";
  String addressText = "Address";
  String emailText = "Email";
  String phoneText = "Phone";
  String websiteText = "Website";
  bool _translationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTranslations();
  }

  Future<void> _initializeTranslations() async {
    final languageService = await LanguageService.getInstance();
    
    final translations = await Future.wait([
      languageService.translate('Contact Information'),
      languageService.translate('Address'),
      languageService.translate('Email'),
      languageService.translate('Phone'),
      languageService.translate('Website'),
    ]);
    
    if (mounted) {
      setState(() {
        contactInfoText = translations[0];
        addressText = translations[1];
        emailText = translations[2];
        phoneText = translations[3];
        websiteText = translations[4];
        _translationsInitialized = true;
      });
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
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
    return Card(
      elevation: 2,
      color: Colors.grey[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contactInfoText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(height: 24),
            if (widget.company.address != null) ...[
              _buildInfoRow(
                Icons.location_on,
                addressText,
                FutureBuilder<String>(
                  future: widget.company.address!.getTranslatedFullAddress(),
                  builder: (context, snapshot) {
                    final address = widget.company.address;
                    if (snapshot.hasData) {
                      return Text(
                        snapshot.data!,
                        overflow: TextOverflow.visible,
                      );
                    }
                    return Text(
                      '${address!.street}, ${address.city}, ${address.state}, ${address.zip}',
                      overflow: TextOverflow.visible,
                    );
                  }
                ),
              ),
              SizedBox(height: 12),
            ],
            if (widget.company.email != null) ...[
              _buildInfoRow(
                Icons.email,
                emailText,
                Text(
                  widget.company.email!,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(height: 12),
            ],
            if (widget.company.phone != null) ...[
              _buildInfoRow(
                Icons.phone,
                phoneText,
                InkWell(
                  onTap: () => _launchPhone(widget.company.phone!),
                  child: Text(
                    widget.company.phone!,
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
            ],
            if (widget.company.website != null) ...[
              _buildInfoRow(
                Icons.language,
                websiteText,
                InkWell(
                  onTap: () => _launchURL(widget.company.website!),
                  child: Text(
                    widget.company.website!,
                    style: TextStyle(
                      color: Colors.blue,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              value,
            ],
          ),
        ),
      ],
    );
  }
}