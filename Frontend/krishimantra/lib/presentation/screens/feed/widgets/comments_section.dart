import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/models/comment_modal.dart';
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
      color: Colors.white,
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
                  ),
                )),
          ),
          Obx(() {
            if (feedController.isLoadingComments.value &&
                feedController.comments.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            } else if (feedController.comments.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No comments yet'),
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
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
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
