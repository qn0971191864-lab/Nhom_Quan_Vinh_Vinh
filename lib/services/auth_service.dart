import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../user.dart';

class AuthIdentity {
  const AuthIdentity({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
}

abstract interface class AuthClient {
  Stream<AuthIdentity?> authStateChanges();

  Future<AuthIdentity> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> updateDisplayName(String displayName);

  Future<AuthIdentity> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

abstract interface class UserProfileStore {
  Future<Map<String, dynamic>?> getProfile(String uid);

  Future<void> setProfile(String uid, Map<String, dynamic> profile);
}

class AuthService {
  AuthService({AuthClient? auth, UserProfileStore? profiles})
    : _auth = auth ?? _FirebaseAuthClient(firebase_auth.FirebaseAuth.instance),
      _profiles = profiles ?? _FirestoreUserProfileStore();

  final AuthClient _auth;
  final UserProfileStore _profiles;

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges().asyncMap((identity) async {
        if (identity == null) {
          return null;
        }
        final profile = await _profiles.getProfile(identity.uid);
        if (profile != null) {
          return User.fromMap(profile)..firebaseUid = identity.uid;
        }
        return User(
          firebaseUid: identity.uid,
          fullname: identity.displayName ?? '',
          email: identity.email ?? '',
          avatar: identity.photoUrl ?? '',
        );
      });

  Future<User> register({
    required String email,
    required String password,
    required String fullname,
    String avatar = '',
  }) async {
    if (fullname.trim().isEmpty) {
      throw ArgumentError('Họ và tên không được để trống.');
    }
    final identity = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _auth.updateDisplayName(fullname);
    return _synchronizeProfile(
      AuthIdentity(
        uid: identity.uid,
        email: identity.email ?? email,
        displayName: fullname,
        photoUrl: identity.photoUrl,
      ),
      initialProfile: {'fullname': fullname, 'avatar': avatar, 'role': 'USER'},
    );
  }

  Future<User> signIn({required String email, required String password}) async {
    final identity = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _synchronizeProfile(identity);
  }

  Future<void> signOut() => _auth.signOut();

  Future<User> _synchronizeProfile(
    AuthIdentity identity, {
    Map<String, dynamic> initialProfile = const {},
  }) async {
    final existing = await _profiles.getProfile(identity.uid);
    final profile = <String, dynamic>{...initialProfile, ...?existing};
    final fullname = identity.displayName;
    final email = identity.email;
    final photoUrl = identity.photoUrl;
    profile['firebaseUid'] = identity.uid;
    if (email != null) {
      profile['email'] = email;
    }
    if (fullname != null && fullname.isNotEmpty) {
      profile['fullname'] = fullname;
    } else {
      profile.putIfAbsent('fullname', () => '');
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      profile['avatar'] = photoUrl;
    } else {
      profile.putIfAbsent('avatar', () => '');
    }
    profile.putIfAbsent('role', () => 'USER');
    profile.putIfAbsent('createdAt', () => Timestamp.now());

    if (profile['role'] == 'USER') {
      await _profiles.setProfile(identity.uid, profile);
    }
    final user = User.fromMap(profile)..firebaseUid = identity.uid;
    return user;
  }
}

class _FirebaseAuthClient implements AuthClient {
  _FirebaseAuthClient(this._auth);

  final firebase_auth.FirebaseAuth _auth;

  @override
  Stream<AuthIdentity?> authStateChanges() =>
      _auth.authStateChanges().map(_toIdentity);

  @override
  Future<AuthIdentity> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _identityFromUser(credential.user);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName);
  }

  @override
  Future<AuthIdentity> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _identityFromUser(credential.user);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  AuthIdentity? _toIdentity(firebase_auth.User? user) =>
      user == null ? null : _identityFromUser(user);

  AuthIdentity _identityFromUser(firebase_auth.User? user) {
    if (user == null) {
      throw StateError('Firebase Authentication returned no user.');
    }
    return AuthIdentity(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }
}

class _FirestoreUserProfileStore implements UserProfileStore {
  _FirestoreUserProfileStore([FirebaseFirestore? firestore])
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final snapshot = await _firestore.collection('users').doc(uid).get();
    return snapshot.data();
  }

  @override
  Future<void> setProfile(String uid, Map<String, dynamic> profile) =>
      _firestore
          .collection('users')
          .doc(uid)
          .set(profile, SetOptions(merge: true));
}
