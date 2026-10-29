import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plant_health/core/di/injection.dart';
import 'package:plant_health/core/theme/app_colors.dart';
import 'package:plant_health/core/utils/bangla_format.dart';
import 'package:plant_health/features/community/data/community_repository.dart';
import 'package:plant_health/features/community/presentation/ask_question_page.dart';
import 'package:plant_health/features/community/presentation/post_detail_page.dart';
import 'package:plant_health/features/voice_assistant/presentation/voice_guide.dart';
import 'package:url_launcher/url_launcher.dart';

/// Farmers' questions from Firestore, newest first, with a button to ask
/// one and the agriculture call centre for urgent help.
class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  static const callCentre = '16123';

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  final _repo = getIt<CommunityRepository>();
  late Stream<List<CommunityPost>> _posts = _repo.watchPosts();
  String _query = '';

  /// Firestore keeps retrying quietly when offline or switched off; after
  /// this the feed says so instead of spinning forever.
  bool _slow = false;
  Timer? _slowTimer;

  @override
  void initState() {
    super.initState();
    _startSlowTimer();
  }

  void _startSlowTimer() {
    _slowTimer?.cancel();
    _slow = false;
    _slowTimer = Timer(const Duration(seconds: 12), () {
      if (mounted) setState(() => _slow = true);
    });
  }

  void _reload() => setState(() {
    _posts = _repo.watchPosts();
    _startSlowTimer();
  });

  @override
  void dispose() {
    _slowTimer?.cancel();
    super.dispose();
  }

  Future<void> _call() async {
    final ok = await launchUrl(
      Uri(scheme: 'tel', path: CommunityPage.callCentre),
    );
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ফোন থেকে ১৬১২৩ নম্বরে কল করুন।')),
      );
    }
  }

  void _ask() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const AskQuestionPage()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F6),
      appBar: AppBar(
        title: const Text('কমিউনিটি'),
        actions: const [VoiceGuideButton(screen: GuideScreen.community)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ask,
        icon: const Icon(Icons.edit_rounded),
        label: const Text('প্রশ্ন করুন'),
      ),
      body: StreamBuilder<List<CommunityPost>>(
        stream: _posts,
        builder: (context, snap) {
          if (snap.hasData) _slowTimer?.cancel();
          final posts = (snap.data ?? const <CommunityPost>[])
              .where(
                (p) =>
                    _query.isEmpty ||
                    p.title.contains(_query) ||
                    p.body.contains(_query),
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
            children: [
              TextField(
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'কমিউনিটিতে খুঁজুন',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFFE3E8E4)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFFE3E8E4)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _CallCard(onCall: _call),
              const SizedBox(height: 16),
              if (snap.hasError)
                _Notice(
                  icon: Icons.cloud_off_rounded,
                  text: _errorText(snap.error),
                  onRetry: _reload,
                )
              else if (!snap.hasData)
                _slow
                    ? _Notice(
                        icon: Icons.wifi_off_rounded,
                        text:
                            'কমিউনিটি লোড হচ্ছে না। ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।',
                        onRetry: _reload,
                      )
                    : const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(child: CircularProgressIndicator()),
                      )
              else if (posts.isEmpty)
                _Notice(
                  icon: Icons.forum_outlined,
                  text: _query.isEmpty
                      ? 'এখনো কোনো প্রশ্ন নেই। প্রথম প্রশ্নটি আপনিই করুন!'
                      : '"$_query" দিয়ে কিছু পাওয়া যায়নি।',
                )
              else
                for (final p in posts) ...[
                  PostCard(post: p),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }

  static String _errorText(Object? e) =>
      e is FirebaseException && e.code == 'permission-denied'
      ? 'কমিউনিটি এখনো চালু হয়নি। একটু পরে আবার চেষ্টা করুন।'
      : 'কমিউনিটি লোড করা যায়নি। আবার চেষ্টা করুন।';
}

/// One question in the feed; tapping opens it with its answers.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.post, this.expanded = false});

  final CommunityPost post;

  /// On the detail page: full text, no tap.
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final liked = uid != null && post.likes.contains(uid);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: expanded
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PostDetailPage(post: post)),
              ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3E8E4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.photo != null)
                Image.memory(
                  post.photo!,
                  height: expanded ? null : 180,
                  width: double.infinity,
                  fit: expanded ? BoxFit.fitWidth : BoxFit.cover,
                  gaplessPlayback: true,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.leafSoft,
                          child: Icon(
                            Icons.person_rounded,
                            size: 18,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.district.isEmpty
                                    ? post.authorName
                                    : '${post.authorName} • ${post.district}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                              Text(
                                '${timeAgo(post.createdAt)} • 🌾 ধান',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      post.title,
                      maxLines: expanded ? null : 2,
                      overflow: expanded ? null : TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (post.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        post.body,
                        maxLines: expanded ? null : 3,
                        overflow: expanded ? null : TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 16, indent: 14, endIndent: 14),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 14, 6),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: uid == null
                          ? null
                          : () => getIt<CommunityRepository>()
                                .toggleLike(post, uid)
                                .catchError((_) {}),
                      icon: Icon(
                        liked
                            ? Icons.thumb_up_alt_rounded
                            : Icons.thumb_up_alt_outlined,
                        size: 20,
                      ),
                      label: Text(BanglaFormat.digits(post.likes.length)),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: Colors.black54,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'উত্তর ${BanglaFormat.digits(post.answerCount)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "৫ মিনিট আগে"; a just-sent post has no server time yet.
String timeAgo(DateTime? t, {DateTime? now}) {
  if (t == null) return 'এইমাত্র';
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'এইমাত্র';
  if (d.inHours < 1) return '${BanglaFormat.digits(d.inMinutes)} মিনিট আগে';
  if (d.inDays < 1) return '${BanglaFormat.digits(d.inHours)} ঘণ্টা আগে';
  if (d.inDays < 30) return '${BanglaFormat.digits(d.inDays)} দিন আগে';
  return '${BanglaFormat.digits(t.day)}/${BanglaFormat.digits(t.month)}/'
      '${BanglaFormat.digits(t.year)}';
}

class _CallCard extends StatelessWidget {
  const _CallCard({required this.onCall});

  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.leafSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent_rounded, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'জরুরি পরামর্শ: কৃষি কল সেন্টার ১৬১২৩',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton.icon(
            onPressed: onCall,
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('কল'),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.onRetry});

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, size: 40, color: Colors.black38),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('আবার চেষ্টা')),
        ],
      ),
    );
  }
}
