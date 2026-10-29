import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.district,
    required this.title,
    required this.body,
    required this.createdAt,
    this.photo,
    this.answerCount = 0,
    this.likes = const [],
  });

  final String id;
  final String authorId;
  final String authorName;
  final String district;
  final String title;
  final String body;

  /// Null until the server has stamped the time (a just-sent post).
  final DateTime? createdAt;

  /// JPEG bytes, already shrunk for the feed.
  final Uint8List? photo;
  final int answerCount;

  /// Uids of farmers who liked it.
  final List<String> likes;

  factory CommunityPost.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final photo = d['photo'] as String?;
    return CommunityPost(
      id: doc.id,
      authorId: d['authorId'] as String? ?? '',
      authorName: d['authorName'] as String? ?? 'কৃষক',
      district: d['district'] as String? ?? '',
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      photo: photo == null ? null : base64Decode(photo),
      answerCount: (d['answerCount'] as num?)?.toInt() ?? 0,
      likes: List<String>.from(d['likes'] as List? ?? const []),
    );
  }
}

class CommunityAnswer {
  const CommunityAnswer({
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  final String authorName;
  final String text;
  final DateTime? createdAt;

  factory CommunityAnswer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CommunityAnswer(
      authorName: d['authorName'] as String? ?? 'কৃষক',
      text: d['text'] as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// Farmers' questions and answers in Firestore: `posts/{id}` and
/// `posts/{id}/answers/{id}`. Photos are shrunk and kept in the post
/// itself, so no Cloud Storage (paid plan) is needed. `firestore.rules`
/// checks every write.
class CommunityRepository {
  CommunityRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const maxTitle = 200;
  static const maxBody = 2500;
  static const maxAnswer = 1000;

  /// Firestore retries quietly while offline or switched off; past this a
  /// write is reported as failed instead of spinning forever.
  static const _writeTimeout = Duration(seconds: 15);

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection('posts');

  /// Newest 50 posts, live. An empty list from the phone's cache is
  /// skipped: offline (or with Firestore unreachable) it would wrongly say
  /// "no questions yet" instead of still loading.
  Stream<List<CommunityPost>> watchPosts() => _posts
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots(includeMetadataChanges: true)
      .where((s) => !(s.metadata.isFromCache && s.docs.isEmpty))
      .map((s) => s.docs.map(CommunityPost.fromDoc).toList());

  Stream<CommunityPost?> watchPost(String id) => _posts
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? CommunityPost.fromDoc(d) : null);

  Stream<List<CommunityAnswer>> watchAnswers(String postId) => _posts
      .doc(postId)
      .collection('answers')
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(CommunityAnswer.fromDoc).toList());

  Future<void> addPost({
    required String authorId,
    required String authorName,
    required String district,
    required String title,
    required String body,
    Uint8List? photo,
  }) async {
    final data = <String, dynamic>{
      'authorId': authorId,
      'authorName': authorName,
      'district': district,
      'crop': 'ধান',
      'title': title.trim(),
      'body': body.trim(),
      'answerCount': 0,
      'likes': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (photo != null) data['photo'] = base64Encode(shrinkPhoto(photo));
    await _posts.add(data).timeout(_writeTimeout);
  }

  /// Saves the answer and counts it on the post, together.
  Future<void> addAnswer({
    required String postId,
    required String authorId,
    required String authorName,
    required String text,
  }) async {
    final post = _posts.doc(postId);
    final batch = _db.batch()
      ..set(post.collection('answers').doc(), {
        'authorId': authorId,
        'authorName': authorName,
        'text': text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..update(post, {'answerCount': FieldValue.increment(1)});
    await batch.commit().timeout(_writeTimeout);
  }

  Future<void> toggleLike(CommunityPost post, String uid) => _posts
      .doc(post.id)
      .update({
        'likes': post.likes.contains(uid)
            ? FieldValue.arrayRemove([uid])
            : FieldValue.arrayUnion([uid]),
      })
      .timeout(_writeTimeout);

  /// Only the author may delete (also enforced by the rules).
  Future<void> deletePost(String postId) =>
      _posts.doc(postId).delete().timeout(_writeTimeout);

  /// Longest side 720 px, JPEG quality 70: a phone photo becomes roughly
  /// 50-120 KB, well under Firestore's 1 MB document limit.
  static Uint8List shrinkPhoto(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw const FormatException('ছবিটি পড়া যায়নি');
    final resized = decoded.width >= decoded.height
        ? (decoded.width > 720 ? img.copyResize(decoded, width: 720) : decoded)
        : (decoded.height > 720
              ? img.copyResize(decoded, height: 720)
              : decoded);
    return img.encodeJpg(resized, quality: 70);
  }
}
