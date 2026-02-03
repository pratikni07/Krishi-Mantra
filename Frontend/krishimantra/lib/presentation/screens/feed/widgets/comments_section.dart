import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/comment_model.dart';
import '../../../../core/constants/colors.dart';
import '../../../controllers/feed_controller.dart';
import 'comment_item.dart';

class CommentsSection extends StatelessWidget {
  final FeedController feedController;
  final Function(CommentModel) onReply;

  const CommentsSection({
    Key? key,
    required this.feedController,
    required this.onReply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Obx(() => Text(
                  'Comments (${feedController.totalComments})',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                )),
          ),
          Obx(() {
            if (feedController.isLoadingComments.value &&
                feedController.comments.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: AppColors.green));
            } else if (feedController.comments.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No comments yet',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            } else {
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: feedController.comments.length,
                itemBuilder: (context, index) => CommentItem(
                  comment: feedController.comments[index],
                  onReply: onReply,
                ),
              );
            }
          }),
          Obx(() {
            if (feedController.isLoadingComments.value &&
                feedController.comments.isNotEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Image.asset(
                    'assets/Images/krishimantraloading.gif',
                    height: 50,
                    width: 50,
                  ),
                ),
              );
            }
            return const SizedBox();
          }),
        ],
      ),
    );
  }
}
