import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/core/utils/bangla_format.dart';
import 'package:plant_health/features/community/data/community_repository.dart';
import 'package:plant_health/features/community/presentation/ask_question_page.dart';
import 'package:plant_health/features/community/presentation/community_page.dart';

/// One question, live, with its answers and a box to answer.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.post});

  final CommunityPost post;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final _repo = getIt<CommunityRepository>();
  final _answer = TextEditingController();
  late final _post = _repo.watchPost(widget.post.id);
  late final _answers = _repo.watchAnswers(widget.post.id);
  bool _sending = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  void _say(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _send() async {
    final text = _answer.text.trim();
    if (text.isEmpty) return;
    final me = await currentFarmer();
    if (me == null) return _say(notSignedIn);
    setState(() => _sending = true);
    try {
      await _repo.addAnswer(
        postId: widget.post.id,
        authorId: me.uid,
        authorName: me.name,
        text: text,
      );
      _answer.clear();
      if (mounted) FocusScope.of(context).unfocus();
    } catch (e) {
      debugPrint('💬 Answer failed: $e');
      if (mounted) _say('পাঠানো যায়নি। ইন্টারনেট দেখে আবার চেষ্টা করুন।');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('প্রশ্নটি মুছবেন?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('না'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('মুছুন'),
          ),
        ],
      ),
    );
    if (sure != true) return;
    try {
      await _repo.deletePost(widget.post.id);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _say('মোছা যায়নি। আবার চেষ্টা করুন।');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = FirebaseAuth.instance.currentUser?.uid == widget.post.authorId;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      appBar: AppBar(
        title: const Text('প্রশ্ন'),
        actions: [
          if (mine)
            IconButton(
              tooltip: 'মুছুন',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<CommunityPost?>(
            stream: _post,
            initialData: widget.post,
            builder: (context, snap) =>
                PostCard(post: snap.data ?? widget.post, expanded: true),
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<CommunityAnswer>>(
            stream: _answers,
            builder: (context, snap) {
              final answers = snap.data ?? const <CommunityAnswer>[];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'উত্তর (${BanglaFormat.digits(answers.length)})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (snap.hasData && answers.isEmpty)
                    const Text(
                      'এখনো উত্তর নেই। জানা থাকলে নিচে লিখে সাহায্য করুন।',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                  for (final a in answers) _AnswerTile(answer: a),
                ],
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            8,
            12,
            8 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: TextField(
            controller: _answer,
            maxLength: CommunityRepository.maxAnswer,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              hintText: 'উত্তর লিখুন',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              suffixIcon: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'পাঠান',
                      onPressed: _send,
                      icon: const Icon(
                        Icons.send_rounded,
                        color: AppColors.primary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnswerTile extends StatelessWidget {
  const _AnswerTile({required this.answer});

  final CommunityAnswer answer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E8E4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${answer.authorName} • ${timeAgo(answer.createdAt)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(answer.text, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
