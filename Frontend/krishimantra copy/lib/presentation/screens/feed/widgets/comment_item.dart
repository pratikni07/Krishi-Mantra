// widgets/comment_item.dart
import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/colors.dart';
import '../../../../data/models/comment_modal.dart';

class CommentItem extends StatefulWidget {
  final CommentModel comment;
  final Function(CommentModel) onReply;

  const CommentItem({
    Key? key,
    required this.comment,
    required this.onReply,
  }) : super(key: key);

  @override
  State<CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<CommentItem> {
  static const int initialRepliesCount = 2;
  bool showAllReplies = false;

  List<ReplyModel> get visibleReplies {
    if (showAllReplies ||
        widget.comment.replies.length <= initialRepliesCount) {
      return widget.comment.replies;
    }
    return widget.comment.replies.take(initialRepliesCount).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: AppColors.faintGreen, // Using your AppColors
            width: 2,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(widget.comment.profilePhoto),
                radius: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.comment.content),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          timeago.format(widget.comment.createdAt),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => widget.onReply(widget.comment),
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (widget.comment.replies.isNotEmpty)
            _ReplyList(
              replies: visibleReplies,
              totalReplies: widget.comment.replies.length,
              showAllReplies: showAllReplies,
              onShowMoreTap: () {
                setState(() {
                  showAllReplies = true;
                });
              },
            ),
        ],
      ),
    );
  }
}

class _ReplyList extends StatelessWidget {
  final List<ReplyModel> replies;
  final int totalReplies;
  final bool showAllReplies;
  final VoidCallback onShowMoreTap;

  const _ReplyList({
    Key? key,
    required this.replies,
    required this.totalReplies,
    required this.showAllReplies,
    required this.onShowMoreTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 48, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...replies.map((reply) => _ReplyItem(reply: reply)),
          if (!showAllReplies && totalReplies > 2)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GestureDetector(
                onTap: onShowMoreTap,
                child: Text(
                  'Show ${totalReplies - 2} more replies',
                  style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReplyItem extends StatelessWidget {
  final ReplyModel reply;

  const _ReplyItem({
    Key? key,
    required this.reply,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage(reply.profilePhoto),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reply.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reply.content,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(reply.createdAt),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
