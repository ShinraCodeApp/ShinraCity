import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';

class FirebasePointsDatasource {
  final FirebaseFirestore _firestore;

  FirebasePointsDatasource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  Future<int> getUserPoints(String userId) async {
    final doc = await _firestore.collection(AppConstants.usersCollection).doc(userId).get();
    return doc.data()?['availablePoints'] ?? 0;
  }

  Future<void> addPoints({
    required String userId,
    required int points,
    required String reason,
    String? commerceId,
    String? promotionId,
    String? couponId,
  }) async {
    await _firestore.runTransaction((t) async {
      final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);
      final userDoc = await t.get(userRef);
      final data = userDoc.data()!;

      final newTotal = (data['totalPoints'] ?? 0) + points;
      final newAvailable = (data['availablePoints'] ?? 0) + points;
      final newLevel = _calculateLevel(newTotal);

      t.update(userRef, {
        'totalPoints': newTotal,
        'availablePoints': newAvailable,
        'level': newLevel,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final txRef = _firestore.collection('points_transactions').doc();
      t.set(txRef, {
        'userId': userId,
        'points': points,
        'type': 'earned',
        'reason': reason,
        'commerceId': commerceId,
        'promotionId': promotionId,
        'couponId': couponId,
        'balanceAfter': newAvailable,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deductPoints({
    required String userId,
    required int points,
    required String reason,
    String? rewardId,
  }) async {
    await _firestore.runTransaction((t) async {
      final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);
      final userDoc = await t.get(userRef);
      final data = userDoc.data()!;
      final available = data['availablePoints'] ?? 0;

      if (available < points) {
        throw Exception('Puntos insuficientes');
      }

      t.update(userRef, {
        'availablePoints': FieldValue.increment(-points),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final txRef = _firestore.collection('points_transactions').doc();
      t.set(txRef, {
        'userId': userId,
        'points': -points,
        'type': 'redeemed',
        'reason': reason,
        'rewardId': rewardId,
        'balanceAfter': available - points,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<Map<String, dynamic>>> getPointsHistory({
    required String userId,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    Query query = _firestore
        .collection('points_transactions')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (lastDoc != null) query = query.startAfterDocument(lastDoc);

    final snapshot = await query.get();
    return snapshot.docs
        .map((d) => {...d.data() as Map<String, dynamic>, 'id': d.id})
        .toList();
  }

  Future<List<Map<String, dynamic>>> getAchievementDefinitions() async {
    final snapshot = await _firestore
        .collection(AppConstants.achievementsCollection)
        .get();
    final docs = snapshot.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();
    docs.sort((a, b) => ((b['pointsReward'] ?? 0) as int).compareTo((a['pointsReward'] ?? 0) as int));
    return docs;
  }

  Future<List<String>> getUserAchievementIds(String userId) async {
    final doc = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();
    return List<String>.from(doc.data()?['achievementIds'] ?? []);
  }

  Future<void> unlockAchievement(String userId, String achievementId) async {
    await _firestore.collection(AppConstants.usersCollection).doc(userId).update({
      'achievementIds': FieldValue.arrayUnion([achievementId]),
    });
  }

  Future<List<Map<String, dynamic>>> getCommerceRewards({
    required String commerceId,
    bool onlyActive = true,
  }) async {
    Query<Map<String, dynamic>> query = _firestore
        .collection(AppConstants.rewardsCollection)
        .where('commerceId', isEqualTo: commerceId);

    if (onlyActive) {
      query = query.where('isActive', isEqualTo: true);
    }

    final snapshot = await query.get();
    final docs = snapshot.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();
    docs.sort((a, b) => ((a['pointsCost'] ?? 0) as int).compareTo((b['pointsCost'] ?? 0) as int));
    return docs;
  }

  Future<List<Map<String, dynamic>>> getAllActiveRewards({
    int limit = 50,
  }) async {
    final snapshot = await _firestore
        .collection(AppConstants.rewardsCollection)
        .where('isActive', isEqualTo: true)
        .limit(limit)
        .get();
    final docs = snapshot.docs.map((d) => <String, dynamic>{...d.data(), 'id': d.id}).toList();
    docs.sort((a, b) => ((a['pointsCost'] ?? 0) as int).compareTo((b['pointsCost'] ?? 0) as int));
    return docs;
  }

  Future<String> createReward(Map<String, dynamic> rewardData) async {
    final ref = _firestore.collection(AppConstants.rewardsCollection).doc();
    await ref.set({
      ...rewardData,
      'redeemedCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> redeemReward({
    required String userId,
    required String rewardId,
    required String commerceId,
  }) async {
    await _firestore.runTransaction((t) async {
      final rewardRef = _firestore.collection(AppConstants.rewardsCollection).doc(rewardId);
      final userRef = _firestore.collection(AppConstants.usersCollection).doc(userId);

      final rewardDoc = await t.get(rewardRef);
      final userDoc = await t.get(userRef);

      final reward = rewardDoc.data()!;
      final user = userDoc.data()!;

      final pointsCost = reward['pointsCost'] as int;
      final userPoints = user['availablePoints'] as int? ?? 0;

      if (userPoints < pointsCost) {
        throw Exception('Puntos insuficientes para canjear esta recompensa');
      }

      final available = reward['availableQuantity'];
      final redeemed = reward['redeemedCount'] ?? 0;
      if (available != null && redeemed >= available) {
        throw Exception('Recompensa agotada');
      }

      t.update(userRef, {
        'availablePoints': FieldValue.increment(-pointsCost),
      });

      t.update(rewardRef, {
        'redeemedCount': FieldValue.increment(1),
      });

      t.set(_firestore.collection('reward_redemptions').doc(), {
        'userId': userId,
        'rewardId': rewardId,
        'commerceId': commerceId,
        'pointsSpent': pointsCost,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<Map<String, dynamic>>> getLeaderboard({
    String? city,
    int limit = 50,
  }) async {
    Query query = _firestore
        .collection(AppConstants.usersCollection)
        .where('isActive', isEqualTo: true)
        .orderBy('totalPoints', descending: true)
        .limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.asMap().entries.map((entry) {
      final data = entry.value.data() as Map<String, dynamic>;
      return {
        'rank': entry.key + 1,
        'userId': entry.value.id,
        'displayName': data['displayName'] ?? 'Anónimo',
        'photoUrl': data['photoUrl'],
        'totalPoints': data['totalPoints'] ?? 0,
        'level': data['level'] ?? 'explorer',
        'achievementCount': (data['achievementIds'] as List?)?.length ?? 0,
      };
    }).toList();
  }

  String _calculateLevel(int totalPoints) {
    if (totalPoints >= AppConstants.levelThresholds['lifetime']!) return 'lifetime';
    if (totalPoints >= AppConstants.levelThresholds['ambassador']!) return 'ambassador';
    if (totalPoints >= AppConstants.levelThresholds['exemplary']!) return 'exemplary';
    if (totalPoints >= AppConstants.levelThresholds['frequent']!) return 'frequent';
    return 'explorer';
  }
}
