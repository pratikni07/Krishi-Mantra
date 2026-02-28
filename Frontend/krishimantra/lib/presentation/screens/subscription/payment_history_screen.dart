import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/colors.dart';
import '../../../core/utils/language_helper.dart';
import '../../../core/utils/translation_manager.dart';
import '../../../data/models/subscription_model.dart';
import '../../controllers/subscription_controller.dart';
import '../../widgets/translated_text.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen>
    with TranslationMixin {
  final controller = Get.find<SubscriptionController>();
  final _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isInitialLoading = true;
  static const String _keyPaymentHistoryTitle = 'subscription_payment_history';
  static const String _keyNoPaymentHistory = 'subscription_no_payment_history';
  static const String _keyPaymentHistoryPlaceholder =
      'subscription_payment_history_placeholder';
  static const String _keySubscriptionPayment = 'subscription_payment_default';
  static const String _keyStatusPaid = 'subscription_status_paid';
  static const String _keyStatusFailed = 'subscription_status_failed';
  static const String _keyStatusRefunded = 'subscription_status_refunded';
  static const String _keyStatusPending = 'subscription_status_pending';
  static const String _keyStatusUnknown = 'subscription_status_unknown';
  static const String _keyMonthJan = 'common_month_jan';
  static const String _keyMonthFeb = 'common_month_feb';
  static const String _keyMonthMar = 'common_month_mar';
  static const String _keyMonthApr = 'common_month_apr';
  static const String _keyMonthMay = 'common_month_may';
  static const String _keyMonthJun = 'common_month_jun';
  static const String _keyMonthJul = 'common_month_jul';
  static const String _keyMonthAug = 'common_month_aug';
  static const String _keyMonthSep = 'common_month_sep';
  static const String _keyMonthOct = 'common_month_oct';
  static const String _keyMonthNov = 'common_month_nov';
  static const String _keyMonthDec = 'common_month_dec';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    updateTranslations();
    TranslationManager.instance.addLanguageChangeListener(
      _handleLanguageChange,
    );
    _loadInitial();
    _scrollController.addListener(_onScroll);
  }

  void _handleLanguageChange() {
    updateTranslations();
  }

  void _registerTranslations() {
    registerTranslation(_keyPaymentHistoryTitle, 'Payment History');
    registerTranslation(_keyNoPaymentHistory, 'No payment history');
    registerTranslation(
        _keyPaymentHistoryPlaceholder, 'Your payments will appear here');
    registerTranslation(_keySubscriptionPayment, 'Subscription Payment');
    registerTranslation(_keyStatusPaid, 'Paid');
    registerTranslation(_keyStatusFailed, 'Failed');
    registerTranslation(_keyStatusRefunded, 'Refunded');
    registerTranslation(_keyStatusPending, 'Pending');
    registerTranslation(_keyStatusUnknown, 'Unknown');
    registerTranslation(_keyMonthJan, 'Jan');
    registerTranslation(_keyMonthFeb, 'Feb');
    registerTranslation(_keyMonthMar, 'Mar');
    registerTranslation(_keyMonthApr, 'Apr');
    registerTranslation(_keyMonthMay, 'May');
    registerTranslation(_keyMonthJun, 'Jun');
    registerTranslation(_keyMonthJul, 'Jul');
    registerTranslation(_keyMonthAug, 'Aug');
    registerTranslation(_keyMonthSep, 'Sep');
    registerTranslation(_keyMonthOct, 'Oct');
    registerTranslation(_keyMonthNov, 'Nov');
    registerTranslation(_keyMonthDec, 'Dec');
  }

  @override
  void dispose() {
    TranslationManager.instance.removeLanguageChangeListener(
      _handleLanguageChange,
    );
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    _currentPage = 1;
    _hasMore = true;
    await controller.loadPaymentHistory(page: 1);
    if (mounted) {
      setState(() => _isInitialLoading = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    _currentPage++;
    final previousCount = controller.paymentHistory.length;
    await controller.loadPaymentHistory(page: _currentPage);
    if (controller.paymentHistory.length == previousCount) {
      _hasMore = false;
    }
    setState(() => _isLoadingMore = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text(
          getTranslation(_keyPaymentHistoryTitle),
          style: const TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.green,
        iconTheme: const IconThemeData(color: AppColors.white),
      ),
      body: _isInitialLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green),
            )
          : Obx(() {
              final payments = controller.paymentHistory;

              if (payments.isEmpty && !_isLoadingMore) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        getTranslation(_keyNoPaymentHistory),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        getTranslation(_keyPaymentHistoryPlaceholder),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _loadInitial,
                color: AppColors.green,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: payments.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == payments.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.green,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildPaymentCard(payments[index]),
                    );
                  },
                ),
              );
            }),
    );
  }

  Widget _buildPaymentCard(PaymentHistory payment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _statusColor(payment.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _statusIcon(payment.status),
              color: _statusColor(payment.status),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  payment.description ??
                      getTranslation(_keySubscriptionPayment),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(payment.createdAt),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                payment.formattedAmount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(payment.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(payment.status),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(payment.status),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'succeeded':
        return AppColors.green;
      case 'failed':
        return AppColors.error;
      case 'refunded':
        return AppColors.warning;
      case 'pending':
        return AppColors.info;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'succeeded':
        return Icons.check_circle;
      case 'failed':
        return Icons.cancel;
      case 'refunded':
        return Icons.replay;
      case 'pending':
        return Icons.schedule;
      default:
        return Icons.receipt;
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      getTranslation(_keyMonthJan),
      getTranslation(_keyMonthFeb),
      getTranslation(_keyMonthMar),
      getTranslation(_keyMonthApr),
      getTranslation(_keyMonthMay),
      getTranslation(_keyMonthJun),
      getTranslation(_keyMonthJul),
      getTranslation(_keyMonthAug),
      getTranslation(_keyMonthSep),
      getTranslation(_keyMonthOct),
      getTranslation(_keyMonthNov),
      getTranslation(_keyMonthDec),
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'succeeded':
        return getTranslation(_keyStatusPaid);
      case 'failed':
        return getTranslation(_keyStatusFailed);
      case 'refunded':
        return getTranslation(_keyStatusRefunded);
      case 'pending':
        return getTranslation(_keyStatusPending);
      default:
        return getTranslation(_keyStatusUnknown);
    }
  }
}
