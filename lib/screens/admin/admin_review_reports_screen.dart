import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:sist_link1/screens/comments/comments_screen.dart'; // Import CommentsScreen

class AdminReviewReportsScreen extends StatefulWidget {
  const AdminReviewReportsScreen({super.key});

  @override
  State<AdminReviewReportsScreen> createState() =>
      _AdminReviewReportsScreenState();
}

class _AdminReviewReportsScreenState extends State<AdminReviewReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _selectedStatusFilter = 'pending'; // Default filter

  final List<Map<String, String>> _filterOptions = [
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'reviewed_dismissed', 'label': 'Dismissed'},
    {
      'value': 'reviewed_approved_content_deleted',
      'label': 'Approved & Deleted',
    },
  ];

  Future<void> _updateReportStatus(String reportId, String newStatus) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report status updated to $newStatus.')),
        );
      }
    } catch (e) {
      print("Error updating report status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update report status: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<bool> _deleteReportedContent(
    // Returns bool
    String contentId,
    String contentType, {
    String? parentPostId,
  }) async {
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete Content'),
          content: Text(
            'Are you sure you want to delete the reported $contentType? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Content'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        if (contentType == 'post') {
          await _firestore.collection('posts').doc(contentId).delete();
        } else if (contentType == 'comment' && parentPostId != null) {
          await _firestore
              .collection('posts')
              .doc(parentPostId)
              .collection('comments')
              .doc(contentId)
              .delete();
        } else {
          // For unsupported types, or if parentPostId is missing for a comment
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cannot delete content of type "$contentType" or missing info.',
                ),
              ),
            );
          }
          return false; // Indicate deletion was not successfully attempted
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reported $contentType deleted successfully.'),
            ),
          );
        }
        return true; // Deletion was confirmed and attempted
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete reported $contentType: ${e.toString()}',
              ),
            ),
          );
        }
        return false; // Deletion attempt failed
      }
    }
    return false; // Dialog was cancelled
  }

  String _formatReportTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat.yMd().add_jm().format(timestamp.toDate());
  }

  Widget _buildReportedPostContent(String postId) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('posts').doc(postId).get(),
      builder: (context, postSnapshot) {
        if (postSnapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Loading post content...',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          );
        }
        if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text(
              'Post content not found or has been deleted.',
              style: TextStyle(color: Colors.redAccent),
            ),
          );
        }
        final postContentData =
            postSnapshot.data!.data() as Map<String, dynamic>;
        final String postCaption =
            postContentData['caption'] ?? '[No caption for this post]';
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
          margin: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reported Post Content:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.blueGrey[800],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                postCaption,
                style: TextStyle(fontSize: 14, color: Colors.black87),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReportedCommentContent(String commentTextSnippet) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
      margin: const EdgeInsets.only(top: 4.0, bottom: 4.0),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reported Comment Snippet:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Colors.blueGrey[800],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            commentTextSnippet,
            style: TextStyle(fontSize: 14, color: Colors.black87),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Query _getReportsQuery() {
    Query query = _firestore.collection('reports');
    query = query.where('status', isEqualTo: _selectedStatusFilter);
    return query.orderBy('timestamp', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Reported Content'),
        backgroundColor: Colors.deepOrangeAccent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              alignment: WrapAlignment.center,
              children:
                  _filterOptions.map((option) {
                    return FilterChip(
                      label: Text(option['label']!),
                      selected: _selectedStatusFilter == option['value'],
                      onSelected: (bool selected) {
                        if (selected) {
                          setState(() {
                            _selectedStatusFilter = option['value']!;
                          });
                        }
                      },
                      selectedColor: Colors.deepOrangeAccent.withOpacity(0.3),
                      checkmarkColor: Colors.black,
                    );
                  }).toList(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getReportsQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error.toString()}'),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No reports found for status: "$_selectedStatusFilter".',
                    ),
                  );
                }
                final reports = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final reportData =
                        reports[index].data() as Map<String, dynamic>;
                    final String reportId = reports[index].id;
                    final String reportedContentId =
                        reportData['reportedContentId'] ?? 'N/A';
                    final String reportedContentType =
                        reportData['reportedContentType'] ?? 'N/A';
                    final String reporterUserId =
                        reportData['reporterUserId'] ?? 'N/A';
                    final String reportedUserId =
                        reportData['reportedUserId'] ?? 'N/A';
                    final String reportedUsername =
                        reportData['reportedUsername'] ?? 'N/A';
                    final String status = reportData['status'] ?? 'N/A';
                    final Timestamp? timestamp =
                        reportData['timestamp'] as Timestamp?;
                    final String? commentTextSnippet =
                        reportData['commentTextSnippet'] as String?;
                    final String? parentContentId =
                        reportData['parentContentId'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Report ID: $reportId',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'Type: $reportedContentType',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (reportedContentType == 'post' &&
                                reportedContentId != 'N/A')
                              _buildReportedPostContent(reportedContentId)
                            else if (reportedContentType == 'comment' &&
                                commentTextSnippet != null)
                              _buildReportedCommentContent(commentTextSnippet)
                            else
                              Text('Content ID: $reportedContentId'),
                            if (reportedContentType == 'comment' &&
                                parentContentId != null)
                              Text(
                                'Parent Post ID: $parentContentId',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            Text(
                              'Reported User: $reportedUsername (ID: $reportedUserId)',
                            ),
                            Text('Reporter ID: $reporterUserId'),
                            Text(
                              'Reported At: ${_formatReportTimestamp(timestamp)}',
                            ),
                            Text(
                              'Status: $status',
                              style: TextStyle(
                                color:
                                    status == 'pending'
                                        ? Colors.orangeAccent[700]
                                        : (status == 'reviewed_dismissed'
                                            ? Colors.blueGrey
                                            : Colors.green[700]),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: [
                                  if (status == 'pending') ...[
                                    TextButton(
                                      child: const Text('Dismiss'),
                                      onPressed:
                                          () => _updateReportStatus(
                                            reportId,
                                            'reviewed_dismissed',
                                          ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      child: const Text(
                                        'Delete & Approve',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      onPressed: () async {
                                        bool deletionConfirmedAndAttempted =
                                            await _deleteReportedContent(
                                              reportedContentId,
                                              reportedContentType,
                                              parentPostId: parentContentId,
                                            );
                                        if (deletionConfirmedAndAttempted) {
                                          await _updateReportStatus(
                                            reportId,
                                            'reviewed_approved_content_deleted',
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                  if (reportedContentType == 'post' &&
                                      reportedContentId != 'N/A')
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.open_in_new,
                                        size: 18,
                                      ),
                                      label: const Text('View Post'),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (context) => CommentsScreen(
                                                  postId: reportedContentId,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  if (reportedContentType == 'comment' &&
                                      parentContentId != null)
                                    TextButton.icon(
                                      icon: const Icon(
                                        Icons.open_in_new,
                                        size: 18,
                                      ),
                                      label: const Text('View Parent Post'),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            Theme.of(
                                              context,
                                            ).colorScheme.secondary,
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (context) => CommentsScreen(
                                                  postId: parentContentId,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
