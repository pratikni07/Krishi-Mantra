import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/constants/colors.dart';

class CommentSection extends StatefulWidget {
  final String productId;
  final List<dynamic> comments;
  final bool isLoading;
  final bool hasMore;
  final Function() onLoadMore;
  final Function(String) onAddComment;
  final Function(String, String) onAddReply;

  const CommentSection({
    Key? key,
    required this.productId,
    required this.comments,
    required this.isLoading,
    required this.hasMore,
    required this.onLoadMore,
    required this.onAddComment,
    required this.onAddReply,
  }) : super(key: key);

  @override
  _CommentSectionState createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  String? _replyingTo;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Comments',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        _buildCommentInput(),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.comments.length + (widget.isLoading ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == widget.comments.length) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: AppColors.green),
                  ),
                );
              }
              return _buildCommentItem(widget.comments[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: _replyingTo != null 
                    ? 'Reply to $_replyingTo...'
                    : 'Add a comment...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: AppColors.green),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SizedBox(width: 8),
          IconButton(
            onPressed: () {
              if (_commentController.text.isNotEmpty) {
                if (_replyingTo != null) {
                  // Handle reply
                  widget.onAddReply(_replyingTo!, _commentController.text);
                  setState(() => _replyingTo = null);
                } else {
                  // Handle new comment
                  widget.onAddComment(_commentController.text);
                }
                _commentController.clear();
              }
            },
            icon: Icon(Icons.send),
            color: AppColors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(dynamic comment) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(comment['userProfilePhoto']),
                  radius: 16,
                ),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment['userName'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      timeago.format(DateTime.parse(comment['createdAt'])),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(comment['text']),
            SizedBox(height: 8),
            TextButton(
              onPressed: () {
                setState(() {
                  _replyingTo = comment['_id'];
                });
              },
              child: Text(
                'Reply',
                style: TextStyle(color: AppColors.green),
              ),
            ),
            if ((comment['replies'] as List).isNotEmpty) ...[
              Divider(),
              ...comment['replies'].map<Widget>((reply) {
                return Padding(
                  padding: EdgeInsets.only(left: 32, top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundImage: NetworkImage(reply['userProfilePhoto']),
                        radius: 12,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  reply['userName'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  timeago.format(DateTime.parse(reply['createdAt'])),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text(
                              reply['text'],
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _commentController.dispose();
    super.dispose();
  }
} 