import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:quan_vinh_vinh_dau_gia/services/auth_service.dart';

void main() {
  group('AuthService', () {
    late _FakeAuthClient auth;
    late _FakeProfileStore profiles;
    late AuthService service;

    setUp(() {
      auth = _FakeAuthClient();
      profiles = _FakeProfileStore();
      service = AuthService(auth: auth, profiles: profiles);
    });

    test(
      'registers and saves a password-free profile by Firebase UID',
      () async {
        final user = await service.register(
          email: 'new@example.com',
          password: 'do-not-store-this',
          fullname: 'New User',
          avatar: 'avatar.png',
        );

        expect(user.firebaseUid, 'firebase-uid-123');
        expect(user.id, 0);
        expect(user.fullname, 'New User');
        expect(user.email, 'new@example.com');
        expect(auth.updatedDisplayName, 'New User');
        expect(profiles.savedUid, 'firebase-uid-123');
        expect(
          profiles.savedProfile,
          containsPair('firebaseUid', 'firebase-uid-123'),
        );
        expect(profiles.savedProfile, isNot(contains('password')));
        expect(profiles.savedProfile, isNot(contains('do-not-store-this')));
        expect(profiles.savedProfile['role'], 'USER');
      },
    );

    test('sign in preserves legacy numeric id and profile fields', () async {
      profiles.documents['firebase-uid-123'] = {
        'id': 48,
        'fullname': 'Saved Name',
        'email': 'old@example.com',
        'role': 'ADMIN',
        'avatar': 'saved.png',
        'createdAt': '2026-09-16',
      };

      final user = await service.signIn(
        email: 'new@example.com',
        password: 'secret',
      );

      expect(user.id, 48);
      expect(user.firebaseUid, 'firebase-uid-123');
      expect(user.fullname, 'Saved Name');
      expect(user.email, 'new@example.com');
      expect(user.role, 'ADMIN');
      expect(user.avatar, 'saved.png');
      expect(profiles.savedUid, 'firebase-uid-123');
    });

    test(
      'does not interpret a numeric Firebase UID as a legacy user id',
      () async {
        auth.uid = '12345';

        final user = await service.signIn(
          email: 'new@example.com',
          password: 'secret',
        );

        expect(user.id, 0);
        expect(user.firebaseUid, '12345');
        expect(profiles.savedUid, '12345');
      },
    );

    test('emits synchronized user profiles and signed-out state', () async {
      final states = service.authStateChanges;
      final firstState = states.first;
      auth.emit(const AuthIdentity(uid: 'firebase-uid-123', email: 'a@b.com'));
      expect((await firstState)?.firebaseUid, 'firebase-uid-123');

      final signedOutState = states.first;
      auth.emit(null);
      expect(await signedOutState, isNull);
    });

    test('signs out through the authentication client', () async {
      await service.signOut();
      expect(auth.signedOut, isTrue);
    });
  });
}

class _FakeAuthClient implements AuthClient {
  final _states = StreamController<AuthIdentity?>.broadcast();
  String uid = 'firebase-uid-123';
  String? updatedDisplayName;
  bool signedOut = false;

  void emit(AuthIdentity? identity) => _states.add(identity);

  @override
  Stream<AuthIdentity?> authStateChanges() => _states.stream;

  @override
  Future<AuthIdentity> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async => AuthIdentity(uid: uid, email: email);

  @override
  Future<void> updateDisplayName(String displayName) async {
    updatedDisplayName = displayName;
  }

  @override
  Future<AuthIdentity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => AuthIdentity(uid: uid, email: email);

  @override
  Future<void> signOut() async {
    signedOut = true;
  }
}

class _FakeProfileStore implements UserProfileStore {
  final documents = <String, Map<String, dynamic>>{};
  String? savedUid;
  Map<String, dynamic> savedProfile = {};

  @override
  Future<Map<String, dynamic>?> getProfile(String uid) async => documents[uid];

  @override
  Future<void> setProfile(String uid, Map<String, dynamic> profile) async {
    savedUid = uid;
    savedProfile = Map<String, dynamic>.from(profile);
    documents[uid] = {...?documents[uid], ...profile};
  }
}
