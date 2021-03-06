import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Logger logger = Logger();

class FirebaseProvider with ChangeNotifier {
  final FirebaseAuth fAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  FirebaseUser _user;

  FirebaseProvider() {
    _prepareUser();
  }

  FirebaseUser getUser() {
    return _user;
  }

  void setUser(FirebaseUser value) {
    _user = value;
    notifyListeners();
  }

  _prepareUser() {
    fAuth.currentUser().then((FirebaseUser currentUser) {
      setUser(currentUser);
    });
  }

  Future<bool> signInWithGoogleAccount() async {
    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.getCredential(
          accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      final FirebaseUser user =
          (await fAuth.signInWithCredential(credential)).user;
      assert(user.email != null);
      assert(user.displayName != null);
      assert(!user.isAnonymous);
      assert(await user.getIdToken() != null);

      final FirebaseUser currentUser = await fAuth.currentUser();
      assert(user.uid == currentUser.uid);
      setUser(user);
      DatabaseReference dbRef = FirebaseDatabase.instance.reference().child('users/${currentUser.uid}');
      final String userToken = await FirebaseMessaging().getToken();
      await dbRef.child('user_state').once().then((DataSnapshot snapshot) {
        if (snapshot.value == null) {
          dbRef.update({
            'user_state': 0,
            'user_token': userToken,
            'total_goal_num': 0,
            'success_goal_num': 0,
            'point': 0,
            'not_refunded_money': 0,
          });
        }
      });
      return true;
    } on Exception catch (e) {
      logger.e(e.toString());
      return false;
    }
  }

  signOut() async {
    await fAuth.signOut();
    await _googleSignIn.signOut();
    setUser(null);
  }
}