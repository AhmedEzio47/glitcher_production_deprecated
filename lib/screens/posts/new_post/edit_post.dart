import 'dart:io';

import 'package:autocomplete_textfield/autocomplete_textfield.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:glitcher/common_widgets/gradient_appbar.dart';
import 'package:glitcher/constants/constants.dart';
import 'package:glitcher/constants/my_colors.dart';
import 'package:glitcher/constants/sizes.dart';
import 'package:glitcher/constants/strings.dart';
import 'package:glitcher/models/game_model.dart';
import 'package:glitcher/models/hashtag_model.dart';
import 'package:glitcher/models/post_model.dart';
import 'package:glitcher/models/user_model.dart';
import 'package:glitcher/screens/posts/new_post/widget/create_bottom_icon.dart';
import 'package:glitcher/screens/posts/new_post/widget/create_post_image.dart';
import 'package:glitcher/screens/posts/new_post/widget/create_post_video.dart';
import 'package:glitcher/screens/posts/new_post/widget/widget_view.dart';
import 'package:glitcher/services/database_service.dart';
import 'package:glitcher/services/notification_handler.dart';
import 'package:glitcher/utils/app_util.dart';
import 'package:glitcher/utils/functions.dart';
import 'package:glitcher/widgets/caching_image.dart';
import 'package:glitcher/widgets/custom_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:random_string/random_string.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' show get;

class EditPost extends StatefulWidget {
  final Post post;
  EditPost({this.post, Key key}) : super(key: key);
  _CreatePostReplyPageState createState() => _CreatePostReplyPageState();
}

class _CreatePostReplyPageState extends State<EditPost> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isScrollingDown = false;
  ScrollController scrollcontroller;

  File _image;
  File _video;
  var _uploadedFileURL;
  String selectedGame = "";
  GlobalKey<AutoCompleteTextFieldState<String>> autocompleteKey = GlobalKey();
  TextEditingController _textEditingController;
  var _typeAheadController = TextEditingController();

  //YoutubePlayer
  //bool _showYoutubeUrl = false;
  String _youtubeId;
  YoutubePlayerController _youtubeController =
      YoutubePlayerController(initialVideoId: 'youtube');

  bool canSubmit = true;

  String _mentionText = '';
  String _hashtagText = '';
  bool newHashtag = true;

  var words = [];

  CreatePostVideo createPostVideo;

  @override
  void dispose() {
    scrollcontroller.dispose();
    _textEditingController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    scrollcontroller = ScrollController();

    createPostVideo = CreatePostVideo(
      video: _video,
      onCrossIconPressed: _onCrossIconPressed,
    );

    _textEditingController = TextEditingController();
    scrollcontroller..addListener(_scrollListener);
    DatabaseService.getGameNames();

    if(widget.post.imageUrl != null) {
      downloadImage(widget.post.imageUrl);
    }

        setState(() {
          _textEditingController.text = widget.post.text;
          _typeAheadController.text = widget.post.game;
          selectedGame = widget.post.game;
        });

        super.initState();

  }

  _scrollListener() {
    if (scrollcontroller.position.userScrollDirection ==
        ScrollDirection.reverse) {}
  }

  void _onCrossIconPressed() {
    setState(() {
      _image = null;
      _video = null;
    });
  }

  void _onImageIconSelected(File file) {
    print('File size: ${file.lengthSync()}');
    if (file.lengthSync() / (1024 * 1024) == 3) {
      customSnackBar(_scaffoldKey, 'Image exceeded 3 Megabytes limit.');
    } else {
      setState(() {
        _image = file;
      });
    }
  }

  void _onVideoIconSelected(File file) {
    print('File size: ${file.lengthSync()}');
    if (file.lengthSync() / (1024 * 1024) == 10) {
      customSnackBar(_scaffoldKey, 'Video exceeded 10 Megabytes limit.');
    } else {
      setState(() {
        print('File xx: ${file.path}');

        _video = file;
        VideoPlayerController controller =
            VideoPlayerController.file(File(_video.path));
        VideoPlayer playerWidget = VideoPlayer(controller);
        createPostVideo = CreatePostVideo(
          video: _video,
          playerWidget: playerWidget,
          onCrossIconPressed: _onCrossIconPressed,
        );
      });
    }
  }

  /// Submit tweet to save in firebase database
  void _submitButton() async {
    if (selectedGame.isEmpty) {
      AppUtil().customSnackBar(_scaffoldKey, 'You must choose a game category');
      return;
    }

    if (_textEditingController.text.isEmpty) {
      AppUtil().customSnackBar(_scaffoldKey, 'Post can\'t be empty');
      return;
    }

    if (_textEditingController.text == null ||
        _textEditingController.text.isEmpty ||
        _textEditingController.text.length > Sizes.maxPostChars ||
        selectedGame.isEmpty) {
      return;
    }
    glitcherLoader.showLoader(context);

    /// If tweet contain image
    /// First image is uploaded on firebase storage
    /// After successful image upload to firebase storage it returns image path
    /// Add this image path to tweet model and save to firebase database
    String postId = widget.post.id;

    await checkIfContainsMention(_textEditingController.text, postId);

    if (_video != null) {
      _uploadedFileURL =
          await AppUtil.uploadFile(_video, context, 'posts_videos/' + postId);
    } else if (_image != null) {
      //await compressAndUploadFile(_image, 'glitchertemp.jpg');
      _uploadedFileURL =
          await AppUtil.uploadFile(_image, context, 'posts_images/' + postId);
    } else {}

    print(_youtubeId);

    var postData = {
      'author': Constants.currentUserID,
      'text': _textEditingController.text,
      'youtubeId': _youtubeId,
      'video': _video != null ? _uploadedFileURL : null,
      'image': _image != null ? _uploadedFileURL : null,
      'likes': 0,
      'dislikes': 0,
      'comments': 0,
      'timestamp': FieldValue.serverTimestamp(),
      'game': selectedGame
    };

    await postsRef.document(postId).setData(postData);

    await checkIfContainsHashtag(_textEditingController.text, postId);

    /// Checks for username in tweet description
    /// If found sends notification to all tagged user
    /// If no user found or not compost tweet screen is closed and redirect back to home page.

    /// Hide running loader on screen
    glitcherLoader.hideLoader();

    /// Navigate back to home page
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onBackPressed,
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          flexibleSpace: gradientAppBar(),
          title: Text('Edit Post'),
          actions: <Widget>[
            IconButton(
              onPressed: () {
                if (canSubmit) {
                  _submitButton();
                } else {
                  print('can\'t submit = $canSubmit');
                }
              },
              icon: Icon(
                Icons.send,
                color: canSubmit
                    ? switchColor(MyColors.lightPrimary, MyColors.darkPrimary)
                    : MyColors.darkGrey,
              ),
            )
          ],
          leading: new IconButton(
            icon: new Icon(Icons.arrow_back),
            onPressed: () {
              _onBackPressed();
            },
          ),
        ),
        backgroundColor: Theme.of(context).backgroundColor,
        body: Container(
          child: Stack(
            children: <Widget>[
              SingleChildScrollView(
                controller: scrollcontroller,
                child: _ComposeTweet(this),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: CreatePostBottomIconWidget(
                  textEditingController: _textEditingController,
                  onImageIconSelected: _onImageIconSelected,
                  onVideoIconSelected: _onVideoIconSelected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _onBackPressed() {
    return showDialog(
          context: context,
          builder: (context) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: new AlertDialog(
              title: new Text('Are you sure?'),
              content: new Text('Do you want to discard the changes?'),
              actions: <Widget>[
                new GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("NO"),
                  ),
                ),
                SizedBox(height: 16),
                new GestureDetector(
                  onTap: () =>
                      Navigator.of(context).pushReplacementNamed('/home'),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text("YES"),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  checkIfContainsMention(String post, String postId) async {
    post.split(' ').forEach((word) async {
      if (word.startsWith('@')) {
        User user =
            await DatabaseService.getUserWithUsername(word.substring(1));

        await NotificationHandler.sendNotification(
            user.id,
            'New post mention',
            Constants.loggedInUser.username + ' mentioned you in a post',
            postId,
            'mention');
      }
    });
  }

  Future checkIfContainsHashtag(String post, String postId) async {
    post.split(' ').forEach((word) async {
      if (word.startsWith('#')) {
        Hashtag hashtag = await DatabaseService.getHashtagWithText(word);

        if (newHashtag) {
          String hashtagId = randomAlphaNumeric(20);
          await hashtagsRef.document(hashtagId).setData({
            'text': word,
            'timestamp': FieldValue.serverTimestamp()
          });

          await hashtagsRef
              .document(hashtagId)
              .collection('posts')
              .document(postId)
              .setData({'timestamp': FieldValue.serverTimestamp()});
        } else {
          await hashtagsRef
              .document(hashtag.id)
              .collection('posts')
              .document(postId)
              .setData({'timestamp': FieldValue.serverTimestamp()});
        }

        return hashtag;
      } else
        return null;
    });
  }

  downloadImage(String url) async {
    //comment out the next two lines to prevent the device from getting
    // the image from the web in order to prove that the picture is
    // coming from the device instead of the web.
    var response = await get(url); // <--2
    var documentDirectory = await getApplicationDocumentsDirectory();
    var firstPath = documentDirectory.path + "/images";
    var filePathAndName = documentDirectory.path + '/images/pic.jpg';
    //comment out the next three lines to prevent the image from being saved
    //to the device to show that it's coming from the internet
    await Directory(firstPath).create(recursive: true); // <-- 1
    File file2 = new File(filePathAndName);             // <-- 2
    file2.writeAsBytesSync(response.bodyBytes);         // <-- 3
    setState(() {
      _image = File(filePathAndName);
    });
  }
}

class _ComposeTweet extends WidgetView<EditPost, _CreatePostReplyPageState> {
  _ComposeTweet(this.viewState) : super(viewState);

  final _CreatePostReplyPageState viewState;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Sizes.fullHeight(context),
      padding: EdgeInsets.only(left: 10, right: 10, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox.shrink(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CacheThisImage(
                    imageUrl: loggedInProfileImageURL,
                    imageShape: BoxShape.circle,
                    width: Sizes.sm_profile_image_w,
                    height: Sizes.sm_profile_image_h,
                    defaultAssetImage: Strings.default_profile_image,
                  )),
              SizedBox(
                width: 10,
              ),
              Expanded(
                child: TextFormField(
                  onChanged: (text) {
                    if (text.length > Sizes.maxPostChars) {
                      viewState.setState(() {
                        viewState.canSubmit = false;
                      });
                    } else {
                      viewState.setState(() {
                        viewState.canSubmit = true;
                      });
                    }

                    // Mention Users
                    viewState.setState(() {
                      viewState.words = text.split(' ');
                      viewState._mentionText = viewState.words.length > 0 &&
                              viewState.words[viewState.words.length - 1]
                                  .startsWith('@')
                          ? viewState.words[viewState.words.length - 1]
                          : '';

                      //Hashtag
                      viewState._hashtagText = viewState.words.length > 0 &&
                              viewState.words[viewState.words.length - 1]
                                  .startsWith('#')
                          ? viewState.words[viewState.words.length - 1]
                          : '';

                      if (viewState._youtubeId == null) {
                        viewState._youtubeId = viewState.words.length > 0 &&
                                (viewState.words[viewState.words.length - 1]
                                        .contains('www.youtube.com') ||
                                    viewState.words[viewState.words.length - 1]
                                        .contains('https://youtu.be'))
                            ? YoutubePlayer.convertUrlToId(
                                viewState.words[viewState.words.length - 1])
                            : null;
                      }
                    });

                    print(viewState.words[viewState.words.length - 1]);
                    print('yotubeId: ${viewState._youtubeId}');
                  },
                  maxLength: Sizes.maxPostChars,
                  minLines: 5,
                  maxLines: 15,
                  autofocus: true,
                  maxLengthEnforced: true,
                  controller: viewState._textEditingController,
                  decoration: InputDecoration(
                      counterText: "",
                      border: InputBorder.none,
                      hintText: 'What\'s in your mind?'),
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          viewState._mentionText.length > 1
              ? ListView.builder(
                  itemCount: Constants.userFriends.length,
                  itemBuilder: (context, index) {
                    String s = Constants.userFriends[index].username;
                    print('username:' + s);
                    if (('@' + s).contains(viewState._mentionText))
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(
                              Constants.userFriends[index].profileImageUrl),
                        ),
                        title: Text(Constants.userFriends[index].username),
                        onTap: () {
                          String tmp = viewState._mentionText
                              .substring(1, viewState._mentionText.length);
                          viewState.setState(() {
                            viewState._mentionText = '';
                            viewState._textEditingController.text += s
                                .substring(
                                    s.indexOf(tmp) + tmp.length, s.length)
                                .replaceAll(' ', '_');
                          });
                        },
                      );

                    return SizedBox();
                  },
                  shrinkWrap: true,
                )
              : SizedBox(),
          viewState._hashtagText.length > 1
              ? ListView.builder(
                  itemCount: Constants.hashtags.length,
                  itemBuilder: (context, index) {
                    String s = Constants.hashtags[index].text;
                    print('hashtag:' + s);
                    if (('#' + s).contains(viewState._hashtagText))
                      return ListTile(
                        title: Text(Constants.hashtags[index].text),
                        onTap: () {
                          viewState.newHashtag = false;
                          String tmp = viewState._hashtagText
                              .substring(1, viewState._hashtagText.length);
                          viewState.setState(() {
                            viewState._hashtagText = '';
                            viewState._textEditingController.text += s
                                .substring(
                                    s.indexOf(tmp) + tmp.length, s.length)
                                .replaceAll(' ', '_');
                          });
                        },
                      );

                    return SizedBox();
                  },
                  shrinkWrap: true,
                )
              : SizedBox(),
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: TypeAheadFormField(
              textFieldConfiguration: TextFieldConfiguration(
                  controller: viewState._typeAheadController,
                  decoration: InputDecoration(
                      icon: Icon(Icons.videogame_asset),
                      hintStyle: TextStyle(
                        color: MyColors.darkGrey,
                      ),
                      hintText: 'Enter Game name')),
              suggestionsCallback: (pattern) {
                return DatabaseService.searchGames(pattern);
              },
              itemBuilder: (context, suggestion) {
                Game game = suggestion as Game;

                return ListTile(
                  title: Text(game.fullName),
                );
              },
              onSuggestionSelected: (suggestion) {
                viewState._typeAheadController.text =
                    (suggestion as Game).fullName;
                viewState.setState(() {
                  viewState.selectedGame = viewState._typeAheadController.text;
                });
              },
              validator: (value) {
                if (value.isEmpty) {
                  return 'Please select a game';
                }
                return '';
              },
              onSaved: (value) => viewState.selectedGame = value,
            ),
          ),
          Flexible(
            child: Stack(
              children: <Widget>[
                CreatePostImage(
                  image: viewState._image,
                  onCrossIconPressed: viewState._onCrossIconPressed,
                ),
              ],
            ),
          ),
          viewState._video != null
              ? Flexible(
                  child: Stack(
                    children: <Widget>[
                      viewState.createPostVideo,
                    ],
                  ),
                )
              : Container(),
        ],
      ),
    );
  }


}