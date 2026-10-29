import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:plant_health/features/community/data/community_repository.dart';
import 'package:plant_health/features/community/presentation/community_page.dart'
    show timeAgo;

Future<CommunityPost> _ask(CommunityRepository repo, {Uint8List? photo}) async {
  await repo.addPost(
    authorId: 'u1',
    authorName: 'করিম',
    district: 'রংপুর',
    title: '  ধানের পাতায় বাদামি দাগ  ',
    body: 'দুই দিন ধরে',
    photo: photo,
  );
  return (await repo.watchPosts().first).single;
}

void main() {
  late CommunityRepository repo;
  setUp(() => repo = CommunityRepository(firestore: FakeFirebaseFirestore()));

  test('a question shows in the feed, trimmed, with no answers yet', () async {
    final post = await _ask(repo);
    expect(post.title, 'ধানের পাতায় বাদামি দাগ');
    expect(post.authorName, 'করিম');
    expect(post.district, 'রংপুর');
    expect(post.answerCount, 0);
    expect(post.likes, isEmpty);
    expect(post.photo, isNull);
  });

  test('answering adds the answer and counts it', () async {
    final post = await _ask(repo);
    await repo.addAnswer(
      postId: post.id,
      authorId: 'u2',
      authorName: 'রহিম',
      text: 'কৃষি অফিসে দেখান',
    );
    final answers = await repo.watchAnswers(post.id).first;
    expect(answers.single.text, 'কৃষি অফিসে দেখান');
    expect((await repo.watchPost(post.id).first)!.answerCount, 1);
  });

  test('like toggles on and off', () async {
    var post = await _ask(repo);
    await repo.toggleLike(post, 'u2');
    post = (await repo.watchPost(post.id).first)!;
    expect(post.likes, ['u2']);
    await repo.toggleLike(post, 'u2');
    expect((await repo.watchPost(post.id).first)!.likes, isEmpty);
  });

  test('a big photo is shrunk to fit a Firestore document', () async {
    final big = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 3000, height: 2000), quality: 95),
    );
    final small = CommunityRepository.shrinkPhoto(big);
    final decoded = img.decodeJpg(small)!;
    expect(decoded.width, 720);
    expect(small.length, lessThan(300000));

    final post = await _ask(repo, photo: big);
    expect(post.photo, isNotNull);
  });

  test('delete removes the question', () async {
    final post = await _ask(repo);
    await repo.deletePost(post.id);
    expect(await repo.watchPosts().first, isEmpty);
  });

  test('time ago in Bangla', () {
    final now = DateTime(2026, 10, 29, 12);
    expect(timeAgo(null), 'এইমাত্র');
    expect(
      timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      '৫ মিনিট আগে',
    );
    expect(
      timeAgo(now.subtract(const Duration(hours: 3)), now: now),
      '৩ ঘণ্টা আগে',
    );
    expect(
      timeAgo(now.subtract(const Duration(days: 2)), now: now),
      '২ দিন আগে',
    );
  });
}
