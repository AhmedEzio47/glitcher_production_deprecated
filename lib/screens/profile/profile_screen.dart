import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:glitcher/constants/constants.dart';
import 'package:glitcher/constants/my_colors.dart';
import 'package:glitcher/constants/sizes.dart';
import 'package:glitcher/constants/strings.dart';
import 'package:glitcher/list_items/post_item.dart';
import 'package:glitcher/models/post_model.dart';
import 'package:glitcher/models/user_model.dart';
import 'package:glitcher/services/auth.dart';
import 'package:glitcher/services/database_service.dart';
import 'package:glitcher/services/notification_handler.dart';
import 'package:glitcher/services/share_link.dart';
import 'package:glitcher/utils/app_util.dart';
import 'package:glitcher/utils/functions.dart';
import 'package:glitcher/widgets/bottom_sheets/profile_image_edit_bottom_sheet.dart';
import 'package:glitcher/widgets/caching_image.dart';
import 'package:glitcher/widgets/circular_clipper.dart';
import 'package:glitcher/widgets/custom_widgets.dart';
import 'package:glitcher/widgets/drawer.dart';
import 'package:glitcher/widgets/image_overlay.dart';
import 'package:random_string/random_string.dart';
import 'package:share/share.dart';

enum ScreenState { to_edit, to_follow, to_save, to_unfollow }

class ProfileScreen extends StatefulWidget {
  final String userId;

  ProfileScreen(this.userId);

  @override
  _ProfileScreenState createState() => _ProfileScreenState(userId);
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _coverImageUrl;
  var _profileImageUrl;
  var _coverImageFile;
  var _profileImageFile;
  double _coverHeight = 200;

  String _descText = 'Description here';
  String _usernameText = 'Username';
  String _nameText = 'name';
  var _descEditingController = TextEditingController()
    ..text = 'Description here';
  var _usernameEditingController = TextEditingController()..text = '';
  var _nameEditingController = TextEditingController()..text = '';

  String userId;

  var userData;

  bool _loading = false;
  bool _isBtnEnabled = true;

  FirebaseUser currentUser;

  bool isFollowing = false;
  bool isFriend = false;

  List<Post> _posts = [];

  Timestamp lastVisiblePostSnapShot;

  ScrollController _scrollController = ScrollController();

  bool _postsReady = false;

  bool isEditingUsername = false;
  bool isEditingName = false;
  bool isEditingDesc = false;

  String _errorMsgUsername = '';

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  _ProfileScreenState(this.userId);

  String validateUsername(String value) {
    String pattern =
        r'^(?=.{4,20}$)(?![_.])(?!.*[_.]{2})[a-zA-Z0-9._]+(?<![_.])$';
    RegExp regExp = new RegExp(pattern);
    if (value.length == 0) {
      AppUtil().showToast("Username is Required");
      setState(() {
        _errorMsgUsername = "Username is Required";
      });
    } else if (!regExp.hasMatch(value)) {
      //AppUtil().showToast("Invalid Username");
      setState(() {
        _errorMsgUsername = "Invalid Username";
      });
      return _errorMsgUsername;
    } else {
      setState(() {
        _errorMsgUsername = null;
      });
    }
    return _errorMsgUsername;
  }

  Future<bool> isUsernameTaken(String username) async {
    final QuerySnapshot result = await Firestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .getDocuments();
    return result.documents.isEmpty;
  }

  @override
  void initState() {
    super.initState();

    ///Set up listener here
    _scrollController
      ..addListener(() {
        if (_scrollController.offset >=
                _scrollController.position.maxScrollExtent &&
            !_scrollController.position.outOfRange) {
          print('reached the bottom');
          nextPosts();
        } else if (_scrollController.offset <=
                _scrollController.position.minScrollExtent &&
            !_scrollController.position.outOfRange) {
          print("reached the top");
        } else {}
      });

    checkUser();
  }

  void checkUser() async {
    currentUser = await Auth().getCurrentUser();

    if (this.userId != currentUser.uid) {
      DocumentSnapshot followSnapshot = await firestore
          .collection('users')
          .document(currentUser.uid)
          .collection('following')
          .document(userId)
          .get();

      setState(() {
        isFollowing = followSnapshot.exists;
      });

      DocumentSnapshot friendSnapshot = await firestore
          .collection('users')
          .document(currentUser.uid)
          .collection('friends')
          .document(userId)
          .get();

      setState(() {
        isFriend = friendSnapshot.exists;
      });
    }

    if (userData == null) {
      loadUserData();
      loadPosts();
    }
  }

  void nextPosts() async {
    var posts;
    posts =
        await DatabaseService.getNextUserPosts(userId, lastVisiblePostSnapShot);

    if (posts.length > 0) {
      setState(() {
        posts.forEach((element) => _posts.add(element));
        this.lastVisiblePostSnapShot = posts.last.timestamp;
      });
    }
  }

  void loadUserData() async {
    setState(() {
      _loading = true;
    });
    print('profileUserID = ${widget.userId}');
    await firestore.collection('users').document(userId).get().then((onValue) {
      setState(() {
        userData = onValue.data;
        _usernameText = onValue.data['username'];
        _nameText = onValue.data['name'];
        _descText = onValue.data['description'];
        _profileImageUrl = onValue.data['profile_url'];
        _coverImageUrl = onValue.data['cover_url'];
        _profileImageFile = null;
        _coverImageFile = null;
        _loading = false;
      });
    });
  }

  save() async {
    setState(() {
      _loading = true;
      _isBtnEnabled = false;
      _descText = _descEditingController.text;
      _usernameText = _usernameEditingController.text;
      _nameText = _nameEditingController.text;
    });

    userData['username'] = _usernameText;
    userData['name'] = _nameText;
    userData['description'] = _descText;

    usersRef.document(userId).updateData(userData);

    String url;

    if (_profileImageFile != null) {
      url = await AppUtil.uploadFile(
        _profileImageFile,
        context,
        'profile_images/$userId',
      );

      setState(() {
        _profileImageUrl = url;
      });

      usersRef.document(userId).updateData({'profile_url': _profileImageUrl});
    }
    if (_coverImageFile != null) {
      url = await AppUtil.uploadFile(
          _coverImageFile, context, 'cover_images/$userId');

      setState(() {
        _coverImageUrl = url;
      });

      usersRef.document(userId).updateData({'cover_url': _coverImageUrl});
    }

    setState(() {
      _profileImageFile = null;
      _coverImageFile = null;
      _loading = false;
      _isBtnEnabled = true;
    });
  }

  Stack _profileAndCover() {
    return Stack(
      alignment: Alignment(0, 0),
      children: <Widget>[
        Container(
          transform: Matrix4.translationValues(0.0, -50.0, 0.0),
          child: Hero(
            tag: _coverImageUrl != null
                ? _coverImageUrl
                : Strings.default_post_image,
            child: ClipShadowPath(
                clipper: CircularClipper(),
                shadow: Shadow(blurRadius: 20.0),
                child: GestureDetector(
                  onTap: () {
                    if (userId == Constants.currentUserID)
                      coverEdit();
                    else {
                      coverDownload();
                    }
                  },
                  child: CacheThisImage(
                    imageUrl: _coverImageUrl,
                    imageShape: BoxShape.rectangle,
                    width: double.infinity,
                    height: 300.0,
                    defaultAssetImage: Strings.default_profile_image,
                  ),
                )),
          ),
        ),
        Positioned.fill(
          bottom: 10.0,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: RawMaterialButton(
                padding: EdgeInsets.all(1.0),
                elevation: 12.0,
                onPressed: () => () {},
                shape: CircleBorder(),
                fillColor: Colors.white,
                child: GestureDetector(
                  onTap: () {
                    if (userId == Constants.currentUserID)
                      profileEdit();
                    else {
                      profileDownload();
                    }
                  },
                  child: CacheThisImage(
                    imageUrl: _profileImageUrl,
                    imageShape: BoxShape.circle,
                    width: Sizes.lg_profile_image_w,
                    height: Sizes.lg_profile_image_h,
                    defaultAssetImage: Strings.default_profile_image,
                  ),
                )),
          ),
        ),
        userId != Constants.currentUserID
            ? Positioned(
                bottom: 0.0,
                left: 20.0,
                child: IconButton(
                  onPressed: isFollowing
                      ? () {
                          unfollowUser();
                        }
                      : () {
                          followUser();
                        },
                  icon: !isFollowing
                      ? Icon(FontAwesome.getIconData('user-plus'))
                      : Icon(FontAwesome.getIconData('user-times')),
                  iconSize: 25.0,
                  color: switchColor(MyColors.lightButtonsBackground,
                      MyColors.darkPrimaryTappedBtn),
                ),
              )
            : Container(),
        isFriend
            ? Positioned(
                bottom: 0.0,
                right: 25.0,
                child: IconButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/conversation',
                        arguments: {'otherUid': userId});
                  },
                  icon: Icon(Icons.chat),
                  iconSize: 25.0,
                  color: switchColor(MyColors.lightButtonsBackground,
                      MyColors.darkPrimaryTappedBtn),
                ),
              )
            : Container(),
      ],
    );
  }

  Widget _build() {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Stack(
        alignment: Alignment(0, 0),
        children: <Widget>[
          SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _profileAndCover(),
                SizedBox(
                  height: 1.0,
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        !isEditingName
                            ? Text(
                                '${_nameText ?? ''} ',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              )
                            : Container(
                                width: 200,
                                child: TextField(
                                  controller: _nameEditingController,
                                )),
                        userId == Constants.currentUserID
                            ? !isEditingName
                                ? IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        isEditingName = true;
                                        _nameEditingController.text = _nameText;
                                      });
                                    })
                                : IconButton(
                                    icon: Icon(
                                      Icons.done,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        isEditingName = false;
                                        _nameText = _nameEditingController.text;
                                      });

                                      updateName();
                                    })
                            : Container(),
                        !isEditingUsername
                            ? Text(
                                '@' + _usernameText,
                                style: TextStyle(
                                    color: switchColor(
                                        MyColors.lightPrimaryTappedBtn,
                                        MyColors.darkPrimaryTappedBtn),
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'WorkSansMedium'),
                              )
                            : Container(
                                width: 150,
                                child: TextFormField(
                                  controller: _usernameEditingController,
                                  onFieldSubmitted: (v) {
                                    setState(() {
                                      isEditingUsername = false;
                                    });

                                    updateUsername();
                                  },
                                )),
                        userId == Constants.currentUserID
                            ? !isEditingUsername
                                ? IconButton(
                                    icon: Icon(
                                      Icons.edit,
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        isEditingUsername = true;
                                        _usernameEditingController.text =
                                            _usernameText;
                                      });
                                    })
                                : IconButton(
                                    icon: Icon(
                                      Icons.done,
                                      size: 16,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        isEditingUsername = false;
                                      });

                                      updateUsername();
                                    })
                            : Container(),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    !isEditingDesc
                        ? Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: Container(
                              constraints: new BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width - 70),
                              child: Text(
                                _descText,
                                style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey,
                                    fontFamily: 'WorkSansMedium'),
                              ),
                            ),
                          )
                        : Container(
                            width: 200,
                            child: TextField(
                              controller: _descEditingController,
                            )),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    userId == Constants.currentUserID
                        ? !isEditingDesc
                            ? IconButton(
                                icon: Icon(
                                  Icons.edit,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isEditingDesc = true;
                                    _descEditingController.text = _descText;
                                  });
                                })
                            : IconButton(
                                icon: Icon(
                                  Icons.done,
                                  size: 18,
                                ),
                                onPressed: () {
                                  setState(() {
                                    isEditingDesc = false;
                                    _descText = _descEditingController.text;
                                  });
                                  updateDesc();
                                })
                        : Container(),
                  ],
                ),
                SizedBox(
                  height: 8,
                ),
                userId == Constants.currentUserID
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          InkWell(
                            onTap: () => Navigator.of(context).pushNamed(
                                '/users',
                                arguments: {'screen_type': 'Followers'}),
                            child: Column(
                              children: <Widget>[
                                Text(
                                  'Followers',
                                  style: TextStyle(color: Colors.grey),
                                ),
                                Text(Constants.userFollowers.length.toString())
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.of(context).pushNamed(
                                '/users',
                                arguments: {'screen_type': 'Following'}),
                            child: Column(
                              children: <Widget>[
                                Text(
                                  'Following',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 14),
                                ),
                                Text(Constants.userFollowing.length.toString())
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pushNamed('/users',
                                  arguments: {'screen_type': 'Friends'});
                            },
                            child: Column(
                              children: <Widget>[
                                Text(
                                  'Friends',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 14),
                                ),
                                Text(Constants.userFriends.length.toString())
                              ],
                            ),
                          ),
                        ],
                      )
                    : Container(),
                SizedBox(
                  height: 8,
                ),
                customDivider(3.0, width: Sizes.fullWidth(context) - 100.0),
                _postsReady == true && _posts.length > 0
                    ? ListView.builder(
                        physics: NeverScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                        itemCount: _posts.length,
                        shrinkWrap: true,
                        itemBuilder: (BuildContext context, int index) {
                          Post post = _posts[index];
                          return FutureBuilder(
                              future:
                                  DatabaseService.getUserWithId(post.authorId),
                              builder: (BuildContext context,
                                  AsyncSnapshot snapshot) {
                                if (!snapshot.hasData) {
                                  return SizedBox.shrink();
                                }
                                User author = snapshot.data;
                                return PostItem(post: post, author: author);
                              });
                        },
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Center(
                            child: Text(
                          'User has no posts yet.',
                          style: TextStyle(fontSize: 20, color: Colors.grey),
                        )),
                      ),
              ],
            ),
          ),
          Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            child: AppBar(
              backgroundColor: Colors.transparent,
              leading: Builder(
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: InkWell(
                    onTap: () => Scaffold.of(context).openDrawer(),
                    child: Icon(
                      const IconData(58311, fontFamily: 'MaterialIcons'),
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              actions: [
                GestureDetector(
                  onTap: () async {
                    await shareProfile(userId, _usernameText, _profileImageUrl);
                  },
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.share,
                          color: Colors.white,
                        ),
                      )
                      //, Text('Share Profile')
                    ],
                  ),
                )
              ],
            ),
          ),
          _loading
              ? Center(
                  child: Image.asset(
                  'assets/images/glitcher_loader.gif',
                  height: 250,
                  width: 250,
                ))
              : Container(
                  width: 0,
                  height: 0,
                ),
        ],
      ),
    );
  }

  shareProfile(String userId, String username, String profileImageUrl) async {
    var userLink = await DynamicLinks.createProfileDynamicLink(
        {'userId': userId, 'text': username, 'imageUrl': profileImageUrl});
    Share.share('Check out @$username profile: $userLink');
    print('Check out @$username profile: $userLink');
  }

  updateUsername() async {
    glitcherLoader.showLoader(context);
    String validUsername = validateUsername(_usernameEditingController.text);
    final valid = await isUsernameTaken(_usernameEditingController.text);

    if (!valid) {
      // username exists
      AppUtil.showSnackBar(context, _scaffoldKey,
          '${_usernameEditingController.text} is already in use. Please choose a different username.');
    } else {
      if (validUsername == null) {
        List search = searchList(_usernameEditingController.text);
        search.addAll(searchList(_nameText));
        await usersRef.document(userId).updateData(
            {'username': _usernameEditingController.text, 'search': search});
        setState(() {
          _usernameText = _usernameEditingController.text;
        });
      } else {
        AppUtil.showSnackBar(context, _scaffoldKey, 'Invalid Username!');
      }
    }
    glitcherLoader.hideLoader();
  }

  searchList(String text) {
    List<String> list = [];
    for (int i = 1; i <= text.length; i++) {
      list.add(text.substring(0, i).toLowerCase());
    }
    return list;
  }

  updateName() async {
    List search = searchList(_usernameText);
    search.addAll(searchList(_nameText));
    await usersRef
        .document(userId)
        .updateData({'name': _nameText, 'search': search});
  }

  updateDesc() async {
    await usersRef.document(userId).updateData({'description': _descText});
  }

  loadPosts() async {
    List<Post> posts;
    posts = await DatabaseService.getUserPosts(userId);
    setState(() {
      _posts = posts;
      this.lastVisiblePostSnapShot = posts.last.timestamp;
      _postsReady = true;
    });
  }

  void followUser() async {
    setState(() {
      _isBtnEnabled = false;
      _loading = true;
    });

    await DatabaseService.followUser(userId);
    checkUser();

    setState(() {
      _loading = false;
      _isBtnEnabled = true;
      isFollowing = false;
    });
  }

  void unfollowUser() async {
    setState(() {
      _isBtnEnabled = false;
      _loading = true;
    });

    await DatabaseService.unfollowUser(userId);
    await NotificationHandler.removeNotification(
        userId, Constants.currentUserID, 'follow');

    checkUser();

    setState(() {
      _loading = false;
      _isBtnEnabled = true;
      isFollowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: _build(),
      drawer: BuildDrawer(),
    );
  }

  coverEdit() async {
    if (_coverImageUrl == null && _coverImageFile == null) {
      ImageEditBottomSheet bottomSheet = ImageEditBottomSheet();
      await bottomSheet.openBottomSheet(context);
      File image = await AppUtil.chooseImage(source: bottomSheet.choice);
      setState(() {
        _coverImageFile = image;
        _coverImageUrl = null;
      });
      glitcherLoader.showLoader(context);
      String url = await AppUtil.uploadFile(
          _coverImageFile, context, 'cover_images/$userId');
      setState(() {
        _coverImageUrl = url;
        _coverImageFile = null;
      });
      await usersRef.document(userId).updateData({'cover_url': _coverImageUrl});
      glitcherLoader.hideLoader();
    } else {
      await showDialog(
          barrierDismissible: true,
          child: Container(
            width: Sizes.sm_profile_image_w,
            height: Sizes.sm_profile_image_h,
            child: ImageOverlay(
              imageUrl: _coverImageUrl,
              imageFile: _coverImageFile,
              btnText: 'Edit',
              btnFunction: () async {
                ImageEditBottomSheet bottomSheet = ImageEditBottomSheet();
                await bottomSheet.openBottomSheet(context);
                File image =
                    await AppUtil.chooseImage(source: bottomSheet.choice);
                setState(() {
                  _coverImageFile = image;
                  _coverImageUrl = null;
                });
                glitcherLoader.showLoader(context);
                String url = await AppUtil.uploadFile(
                    _coverImageFile, context, 'cover_images/$userId');
                setState(() {
                  _coverImageUrl = url;
                  _coverImageFile = null;
                });

                await usersRef
                    .document(userId)
                    .updateData({'cover_url': _coverImageUrl});
                glitcherLoader.hideLoader();

                Navigator.of(context).pop();
              },
            ),
          ),
          context: context);
    }
  }

  profileEdit() async {
    if (_profileImageUrl == null && _profileImageFile == null) {
      ImageEditBottomSheet bottomSheet = ImageEditBottomSheet();
      await bottomSheet.openBottomSheet(context);
      File image = await AppUtil.chooseImage(source: bottomSheet.choice);
      setState(() {
        _profileImageFile = image;
        _profileImageUrl = null;
      });
      glitcherLoader.showLoader(context);
      String url = await AppUtil.uploadFile(
          _profileImageFile, context, 'cover_images/$userId');
      setState(() {
        _profileImageUrl = url;
        _profileImageFile = null;
      });
      await usersRef
          .document(userId)
          .updateData({'profile_url': _profileImageUrl});
      glitcherLoader.hideLoader();
    } else {
      showDialog(
          barrierDismissible: true,
          child: Container(
            width: Sizes.sm_profile_image_w,
            height: Sizes.sm_profile_image_h,
            child: ImageOverlay(
              imageUrl: _profileImageUrl,
              imageFile: _profileImageFile,
              btnText: 'Edit',
              btnFunction: () async {
                ImageEditBottomSheet bottomSheet = ImageEditBottomSheet();
                await bottomSheet.openBottomSheet(context);
                File image =
                    await AppUtil.chooseImage(source: bottomSheet.choice);
                setState(() {
                  _profileImageFile = image;
                  _profileImageUrl = null;
                });
                glitcherLoader.showLoader(context);
                String url = await AppUtil.uploadFile(
                    _profileImageFile, context, 'profile_images/$userId');
                setState(() {
                  _profileImageUrl = url;
                  _profileImageFile = null;
                });
                await usersRef
                    .document(userId)
                    .updateData({'profile_url': _profileImageUrl});
                glitcherLoader.hideLoader();
                Navigator.of(context).pop();
              },
            ),
          ),
          context: context);
    }
  }

  coverDownload() async {
    if (_coverImageUrl == null && _coverImageFile == null)
      return;
    else {
      showDialog(
          barrierDismissible: true,
          child: Container(
            width: Sizes.sm_profile_image_w,
            height: Sizes.sm_profile_image_h,
            child: ImageOverlay(
              imageUrl: _coverImageUrl,
              imageFile: _coverImageFile,
              btnText: 'Download',
              btnFunction: () async {
                downloadImage(
                    _coverImageUrl, randomAlphaNumeric(20) + '_cover');
                Navigator.of(context).pop();
              },
            ),
          ),
          context: context);
    }
  }

  profileDownload() async {
    if (_profileImageUrl == null && _profileImageFile == null)
      return;
    else {
      showDialog(
          barrierDismissible: true,
          child: Container(
            width: Sizes.sm_profile_image_w,
            height: Sizes.sm_profile_image_h,
            child: ImageOverlay(
              imageUrl: _profileImageUrl,
              imageFile: _profileImageFile,
              btnText: 'Download',
              btnFunction: () async {
                await downloadImage(
                    _profileImageUrl, randomAlphaNumeric(20) + '_profile');
                Navigator.of(context).pop();
              },
            ),
          ),
          context: context);
    }
  }

  Future<bool> _onBackPressed() {
    /// Navigate back to home page
    Navigator.of(context).pushReplacementNamed('/home');
  }
}
