import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:glitcher/constants/constants.dart';
import 'package:glitcher/constants/my_colors.dart';
import 'package:glitcher/screens/fullscreen_overaly.dart';
import 'package:glitcher/utils/Loader.dart';
import 'package:glitcher/utils/app_util.dart';
import 'package:glitcher/services/auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ScreenState { to_edit, to_follow, to_save, to_unfollow }

class ProfileScreen extends StatefulWidget {
  final String userId;

  ProfileScreen(this.userId);

  @override
  _ProfileScreenState createState() => _ProfileScreenState(userId);
}

class _ProfileScreenState extends State<ProfileScreen> {
  var _coverImageUrl;
  var _profileImageUrl;
  var _coverImageFile;
  var _profileImageFile;
  var _screenState = ScreenState.to_edit;
  double _coverHeight = 200;

  String _descText = 'Description here';
  String _nameText = 'Username';
  var _descEditingController = TextEditingController()
    ..text = 'Description here';
  var _nameEditingController = TextEditingController()..text = '';
  Firestore _firestore = Firestore.instance;

  String userId;

  var userData;

  int _followers = 0;

  int _following = 0;

  bool _loading = false;

  FirebaseUser currentUser;

  _ProfileScreenState(this.userId);

  @override
  void initState() {
    super.initState();
    checkUser();
  }

  void checkUser() async {
    currentUser = await Auth().getCurrentUser();

    if (this.userId != currentUser.uid) {
      DocumentSnapshot followSnapshot = await _firestore
          .collection('users')
          .document(currentUser.uid)
          .collection('following')
          .document(userId)
          .get();

      bool isFollowing = followSnapshot.exists;

      setState(() {
        if (isFollowing)
          _screenState = ScreenState.to_unfollow;
        else
          _screenState = ScreenState.to_follow;
      });
    }

    if (userData == null) {
      loadUserData();
    }
  }


  void loadUserData() async {
    setState(() {
      _loading = true;
    });
    print('profileUserID = ${widget.userId}');
    await _firestore.collection('users').document(userId).get().then((onValue) {
      setState(() {
        userData = onValue.data;
        _nameText = onValue.data['username'];
        _descText = onValue.data['description'];
        _profileImageUrl = onValue.data['profile_url'];
        _coverImageUrl = onValue.data['cover_url'];
        _followers = onValue.data['followers'];
        _following = onValue.data['following'];

        _profileImageFile = null;
        _coverImageFile = null;
        _loading = false;
      });
    });
  }

  void edit() {
    setState(() {
      _screenState = ScreenState.to_save;
      _nameEditingController..text = _nameText;
      _descEditingController..text = _descText;
    });
  }

  save() async {
    setState(() {
      _screenState = ScreenState.to_edit;
      _descText = _descEditingController.text;
      _nameText = _nameEditingController.text;
    });

    userData['name'] = _nameText;
    userData['description'] = _descText;

    usersRef.document(userId).updateData(userData);

    setState(() {
      _loading = true;
    });

    String url;

    if (_profileImageFile != null) {
      url = await AppUtil.uploadFile(
        _profileImageFile,
        context,
        'profile_img/$userId',
      );

      setState(() {
        _profileImageUrl = url;
      });

      usersRef.document(userId).updateData({'profile_url': _profileImageUrl});
    }
    if (_coverImageFile != null) {
      url = await AppUtil.uploadFile(
          _coverImageFile, context, 'cover_img/$userId');

      setState(() {
        _coverImageUrl = url;
      });

      usersRef.document(userId).updateData({'cover_url': _coverImageUrl});
    }

    setState(() {
      _profileImageFile = null;
      _coverImageFile = null;
      _loading = false;
    });

  }

  Widget profileOverlay(Widget child, double size) {
    if (_screenState == ScreenState.to_edit ||
        _screenState == ScreenState.to_follow ||
        _screenState == ScreenState.to_unfollow) {
      return child;
    }

    return Stack(
      alignment: Alignment(0, 0),
      children: <Widget>[
        child,
        Container(
          child: Icon(FontAwesome.getIconData('camera')),
          height: size,
          width: size,
          decoration: new BoxDecoration(
            color: const Color(0x000000).withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        )
      ],
    );
  }

  Widget coverOverlay(Widget child, double size) {
    if (_screenState == ScreenState.to_edit) {
      return child;
    }
    return Stack(
      alignment: Alignment.bottomRight,
      children: <Widget>[
        child,
        Container(
          margin: EdgeInsets.all(10),
          child: Icon(FontAwesome.getIconData('camera')),
          height: size,
          width: size,
          decoration: new BoxDecoration(
            color: const Color(0x000000).withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        )
      ],
    );
  }

  Stack _profileAndCover() {
    return Stack(
      alignment: Alignment(0, 0),
      children: <Widget>[
        GestureDetector(
          onTap: _screenState == ScreenState.to_save
              ? () async{
            _coverImageFile = await AppUtil.chooseImage();
            setState(() {
              if (_coverImageFile != null) _coverImageUrl = null;
            });

                }
              : () async {
                  if (_coverImageUrl != null) {
                    var result = await showDialog(
                        barrierDismissible: true,
                        context: context,
                        builder: (_) => FullScreenOverlay(
                              url: _coverImageUrl,
                              type: 1,
                              whichImage: 1,
                              userId: userId,
                            ));
                    setState(() {
                      if (result != null) {
                        _coverImageUrl = result;
                      }
                    });
                  } else if (_coverImageFile != null) {
                    var result = await showDialog(
                        context: context,
                        builder: (_) => FullScreenOverlay(
                              url: _coverImageFile,
                              type: 2,
                              whichImage: 1,
                              userId: userId,
                            ));
                    setState(() {
                      if (result != null) {
                        _coverImageUrl = result;
                      }
                    });
                  } else {
                    var result = await showDialog(
                        context: context,
                        builder: (_) => FullScreenOverlay(
                              url: 'images/default_cover.jpg',
                              type: 3,
                              whichImage: 1,
                              userId: userId,
                            ));
                    setState(() {
                      if (result != null) {
                        _coverImageUrl = result;
                      }
                    });
                  }
                },
          child: _coverImageUrl == null
              ? _coverImageFile == null
                  ? Image.asset(
                      'images/default_cover.jpg',
                      fit: BoxFit.fill,
                      width: MediaQuery.of(context).size.width,
                      height: _coverHeight,
                    )
                  : Image.file(
                      _coverImageFile,
                      fit: BoxFit.fill,
                      width: MediaQuery.of(context).size.width,
                      height: _coverHeight,
                    )
              : Image.network(
                  _coverImageUrl,
                  fit: BoxFit.fill,
                  width: MediaQuery.of(context).size.width,
                  height: _coverHeight,
                ),
        ),
        GestureDetector(
            onTap: _screenState == ScreenState.to_save
                ? () async{
                    _profileImageFile = await AppUtil.chooseImage();
                    setState(() {
                      if(_profileImageFile != null) _profileImageUrl = null;
                    });
                  }
                : () async {
                    if (_profileImageUrl != null) {
                      var result = await showDialog(
                          context: context,
                          builder: (_) => FullScreenOverlay(
                                url: _profileImageUrl,
                                type: 1,
                                whichImage: 2,
                                userId: userId,
                              ));
                      setState(() {
                        if (result != null) {
                          _profileImageUrl = result;
                        }
                      });
                    } else if (_profileImageFile != null) {
                      var result = await showDialog(
                          context: context,
                          builder: (_) => FullScreenOverlay(
                                url: _profileImageFile,
                                type: 2,
                                whichImage: 2,
                                userId: userId,
                              ));
                      setState(() {
                        if (result != null) {
                          _profileImageUrl = result;
                        }
                      });
                    } else {
                      var result = await showDialog(
                          context: context,
                          builder: (_) => FullScreenOverlay(
                                url: 'images/default_profile.png',
                                type: 3,
                                whichImage: 2,
                                userId: userId,
                              ));

                      setState(() {
                        if (result != null) {
                          _profileImageUrl = result;
                        }
                      });
                    }
                  },
            child: _profileImageUrl == null
                ? _profileImageFile == null
                    ? profileOverlay(
                        CircleAvatar(
                          radius: 50,
                          backgroundImage:
                              AssetImage('images/default_profile.png'),
                        ),
                        100)
                    : profileOverlay(
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: FileImage(_profileImageFile),
                        ),
                        100)
                : profileOverlay(
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(_profileImageUrl),
                    ),
                    100))
      ],
    );
  }

  Widget _build() {
    return SafeArea(
      child: Stack(
        alignment: Alignment(0, 0),
        children: <Widget>[
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _profileAndCover(),
                SizedBox(
                  height: 10,
                ),
                _screenState == ScreenState.to_edit ||
                        _screenState == ScreenState.to_follow ||
                        _screenState == ScreenState.to_unfollow
                    ? Text(
                        _nameText,
                        style: TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      )
                    : Container(
                        height: 30,
                        width: 200,
                        child: TextField(
                          textAlign: TextAlign.center,
                          controller: _nameEditingController,
                          onChanged: (text) => {},
                          style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                SizedBox(
                  height: 8,
                ),
                _screenState == ScreenState.to_edit ||
                        _screenState == ScreenState.to_follow ||
                        _screenState == ScreenState.to_unfollow
                    ? Text(
                        _descText,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      )
                    : Container(
                        height: 30,
                        width: 200,
                        child: TextField(
                          textAlign: TextAlign.center,
                          controller: _descEditingController,
                          onChanged: (text) => {},
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                SizedBox(
                  height: 8,
                ),
                Divider(
                  color: Colors.grey.shade400,
                ),
                SizedBox(
                  height: 8,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Column(
                      children: <Widget>[
                        Text(
                          'Followers',
                          style: TextStyle(color: Colors.grey),
                        ),
                        Text(_followers.toString())
                      ],
                    ),
                    SizedBox(
                      width: 50,
                    ),
                    Column(
                      children: <Widget>[
                        Text(
                          'Following',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        Text(_following.toString())
                      ],
                    ),
                  ],
                )
              ],
            ),
          ),
          _loading
              ? LoaderTwo()
              : Container(
                  width: 0,
                  height: 0,
                ),
        ],
      ),
    );
  }

  void followUser() async {
    setState(() {
      _loading = true;
    });

    FieldValue timestamp = FieldValue.serverTimestamp();

    await usersRef
        .document(userId)
        .collection('followers')
        .document(Constants.currentUserID)
        .setData({
      'timestamp': FieldValue.serverTimestamp(),
    });

    await usersRef.document(userId).updateData({
      'followers': FieldValue.increment(1),
    });

    await _firestore
        .collection('users')
        .document(Constants.currentUserID)
        .updateData({
      'following': FieldValue.increment(1),
    });

    await usersRef
        .document(Constants.currentUserID)
        .collection('following')
        .document(userId)
        .setData({
      'timestamp': timestamp,
    });

    DocumentSnapshot doc = await usersRef
        .document(userId)
        .collection('following')
        .document(Constants.currentUserID)
        .get();

    if (doc.exists) {
      await usersRef
          .document(Constants.currentUserID)
          .collection('friends')
          .document(userId)
          .setData({'timestamp': FieldValue.serverTimestamp()});

      await usersRef
          .document(Constants.currentUserID)
          .updateData({'friends': FieldValue.increment(1)});

      await usersRef
          .document(userId)
          .collection('friends')
          .document(Constants.currentUserID)
          .setData({'timestamp': FieldValue.serverTimestamp()});

      await usersRef
          .document(userId)
          .updateData({'friends': FieldValue.increment(1)});
    }

    setState(() {
      _loading = false;
      AppUtil().showToast('You started following ' + _nameText);
      _screenState = ScreenState.to_unfollow;
      _followers++;
    });
  }

  void unfollowUser() async {
    setState(() {
      _loading = true;
    });
    await usersRef
        .document(Constants.currentUserID)
        .collection('following')
        .document(userId)
        .delete();

    await usersRef.document(Constants.currentUserID).updateData({
      'following': FieldValue.increment(-1),
    });

    await usersRef
        .document(userId)
        .collection('followers')
        .document(Constants.currentUserID)
        .delete();

    await usersRef.document(userId).updateData({
      'followers': FieldValue.increment(-1),
    });

    DocumentSnapshot doc = await usersRef
        .document(Constants.currentUserID)
        .collection('friends')
        .document(userId)
        .get();

    if (doc.exists) {
      await usersRef
          .document(Constants.currentUserID)
          .collection('friends')
          .document(userId)
          .delete();

      await usersRef
          .document(Constants.currentUserID)
          .updateData({'friends': FieldValue.increment(-1)});
    }

    DocumentSnapshot doc2 = await usersRef
        .document(userId)
        .collection('friends')
        .document(Constants.currentUserID)
        .get();

    if (doc2.exists) {
      await usersRef
          .document(userId)
          .collection('friends')
          .document(Constants.currentUserID)
          .delete();

      await usersRef
          .document(userId)
          .updateData({'friends': FieldValue.increment(-1)});
    }

    setState(() {
      _screenState = ScreenState.to_follow;
      _followers--;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[MyColors.darkCardBG, MyColors.darkBG])),
        ),
        title: Text('Profile'),
      ),
      body: _build(),
      floatingActionButton: FloatingActionButton(
        child: _screenState == ScreenState.to_edit
            ? Icon(MaterialIcons.getIconData('edit'))
            : _screenState == ScreenState.to_save
                ? Icon(MaterialIcons.getIconData('save'))
                : _screenState == ScreenState.to_follow
                    ? Icon(FontAwesome.getIconData('user-plus'))
                    : Icon(FontAwesome.getIconData('user-times')),
        onPressed: _screenState == ScreenState.to_edit
            ? () {
                edit();
              }
            : _screenState == ScreenState.to_save
                ? () {
                    save();
                  }
                : _screenState == ScreenState.to_follow
                    ? () {
                        //VIEWING
                        followUser();
                      }
                    : () {
                        unfollowUser();
                      },
      ),
    );
  }
}
