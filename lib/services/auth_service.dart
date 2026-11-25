import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Everything that talks to Firebase lives here.
/// Each method returns null on SUCCESS, or an error message on FAILURE.
class AuthService {
  // The two Firebase services we use.
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates the account, then saves the profile in the database.
  Future<String?> signUp({
    required String email,
    required String password,
    required String name,
    required String dreamJob,
    required double dreamIncome,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      print('SIGNUP: Starting Firebase Authentication');

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      print(
        'SIGNUP: Authentication completed in ${stopwatch.elapsed.inSeconds}s',
      );

      print('SIGNUP: Starting Firestore write');

      await _db.collection('users').doc(cred.user!.uid).set({
        'name': name,
        'email': email,
        'dreamJob': dreamJob,
        'dreamCareer': dreamJob,
        'dreamIncome': dreamIncome,
        'balance': 0,
        'totalEarned': 0,
        'sessionCount': 0,
        'totalMinutesFocused': 0,
        'streakDays': 1,
        'dailyFocusMinutes': {},
        'subjectFocusStats': {},
        'dailySubjectStats': {},
        'lastActiveDate': DateTime.now().toIso8601String().substring(0, 10),
        'createdAt': FieldValue.serverTimestamp(),
      });


    print(
      'SIGNUP: Firestore completed in ${stopwatch.elapsed.inSeconds}s',
    );

    return null;
  } on FirebaseAuthException catch (e) {
    print('AUTH SIGNUP ERROR: ${e.code} - ${e.message}');
    return _messageFor(e);
  } on FirebaseException catch (e) {
    print('FIRESTORE SIGNUP ERROR: ${e.code}');
    print('FIRESTORE SIGNUP MESSAGE: ${e.message}');
    return 'Database error: ${e.code}';
  } catch (e) {
    print('SIGNUP UNEXPECTED ERROR: $e');
    return 'Something went wrong, please try again';
  }
}


  /// Logs an existing user in.
  Future<String?> logIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _messageFor(e);
    } catch (_) {
      return 'Something went wrong, please try again';
    }
  }

  /// Logs the current user out.
  Future<void> logOut() => _auth.signOut();

  // Turns Firebase's technical error codes into messages for humans.
  String _messageFor(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email already has an account';
      case 'invalid-email':
        return 'This email is not valid';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Wrong email or password';
      case 'network-request-failed':
        return 'No internet connection';
      case 'too-many-requests':
        return 'Too many attempts, try again later';
      default:
        return 'Something went wrong (${e.code})';
    }
  }
}
