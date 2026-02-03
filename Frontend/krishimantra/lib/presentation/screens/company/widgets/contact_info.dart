import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/models/company_model.dart';
import '../../../../data/services/language_service.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/constants/colors.dart';

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
    if (subtitle == null) return const SizedBox.shrink();

    return Column(
      children: [
        ListTile(
          contentPadding: RPadding.symmetric(horizontal: 20, vertical: 8),
          leading: Container(
            padding: RPadding.all(8),
            decoration: BoxDecoration(
              color: AppColors.scaffoldBackground,
              borderRadius: BorderRadius.circular(AppSizes.radiusM),
            ),
            child: Icon(icon, color: AppColors.textGrey, size: AppSizes.iconM),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: AppColors.textGrey,
              fontSize: AppSizes.fontM,
            ),
          ),
          subtitle: Padding(
            padding: EdgeInsets.only(top: AppSizes.paddingXS),
            child: Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[600],
                height: 1.3,
                fontSize: AppSizes.fontS,
              ),
            ),
          ),
          onTap: onTap,
        ),
        if (!isLast)
          Divider(height: 1, indent: AppSizes.paddingL, endIndent: AppSizes.paddingL, color: AppColors.borderLight),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Card(
      elevation: 2,
      color: AppColors.scaffoldBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusL)),
      child: Padding(
        padding: RPadding.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contactInfoText,
              style: TextStyle(
                fontSize: AppSizes.fontL,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(height: AppSizes.paddingXL),
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
                        style: TextStyle(fontSize: AppSizes.fontM),
                      );
                    }
                    return Text(
                      '${address!.street}, ${address.city}, ${address.state}, ${address.zip}',
                      overflow: TextOverflow.visible,
                      style: TextStyle(fontSize: AppSizes.fontM),
                    );
                  }
                ),
              ),
              SizedBox(height: AppSizes.paddingM),
            ],
            if (widget.company.email != null) ...[
              _buildInfoRow(
                Icons.email,
                emailText,
                Text(
                  widget.company.email!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppSizes.fontM),
                ),
              ),
              SizedBox(height: AppSizes.paddingM),
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
                      fontSize: AppSizes.fontM,
                    ),
                  ),
                ),
              ),
              SizedBox(height: AppSizes.paddingM),
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
                      fontSize: AppSizes.fontM,
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
        Icon(icon, size: AppSizes.iconS, color: AppColors.textGrey),
        SizedBox(width: AppSizes.paddingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: AppSizes.fontM,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: AppSizes.paddingXS),
              value,
            ],
          ),
        ),
      ],
    );
  }
}