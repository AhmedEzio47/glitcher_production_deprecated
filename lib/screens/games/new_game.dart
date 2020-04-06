import 'package:dropdownfield/dropdownfield.dart';
import 'package:glitcher/services/permissions_service.dart';
import 'package:glitcher/utils/app_util.dart';
import 'package:glitcher/utils/functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:glitcher/utils/Loader.dart';
import 'package:glitcher/constants/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_icons/flutter_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:random_string/random_string.dart';
import 'package:autocomplete_textfield/autocomplete_textfield.dart';

class NewGame extends StatefulWidget {
  @override
  _NewGameState createState() => _NewGameState();
}

class _NewGameState extends State<NewGame> {
  var _image;
  var _uploadedFileURL;
  var $ranFileName; // Random File Name

  //YoutubePlayer

  final fullNameTextController = TextEditingController();
  final shortNameTextController = TextEditingController();
  final descriptionTextController = TextEditingController();
  final genreTextController = TextEditingController();

  bool _loading = false;
  GlobalKey<AutoCompleteTextFieldState<String>> autocompleteKey =
      new GlobalKey();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void clearVars() {
    setState(() {
      _image = null;
    });
  }

  Future uploadGame(String fullName, String shortName, String description,
      String genre) async {
    setState(() {
      _loading = true;
    });

    String gameId = randomAlphaNumeric(20);

    if (_image != null) {
      _uploadedFileURL = await AppUtil.uploadFile(_image, context, 'games_images/' + gameId);
    }

    await firestore.collection('games').document(gameId).setData({
      'fullName': fullName,
      'shortName': shortName,
      'description': description,
      'genre': genre,
      'image': _image != null ? _uploadedFileURL : null,
      'timestamp': FieldValue.serverTimestamp(),
      'search': searchList(fullName)
    }).then((_) {
      setState(() {
        _loading = false;
        //Navigator.pop(context);
      });

      pushHomeScreen(context);

    });
  }

  searchList(String text) {
    List<String> list = [];
    for (int i = 1; i <= text.length; i++) {
      list.add(text.substring(0, i).toLowerCase());
    }
    return list;
  }

  Widget _buildWidget() {
    return WillPopScope(
      onWillPop: () {
        pushHomeScreen(context);
        return;
      },
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: TextField(
                  controller: fullNameTextController,
                  decoration: new InputDecoration.collapsed(
                      hintText: 'Game full name, ex: Grand Theft Auto V.'),
                  minLines: 1,
                  maxLines: 5,
                  autocorrect: true,
                  autofocus: true,
                ),
              ),
              Divider(
                height: .5,
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: TextField(
                  controller: shortNameTextController,
                  decoration: new InputDecoration.collapsed(
                      hintText: 'Game short name, ex: GTA V.'),
                  minLines: 1,
                  maxLines: 5,
                  autocorrect: true,
                  autofocus: true,
                ),
              ),
              Divider(
                height: .5,
              ),
              Padding(
                padding: const EdgeInsets.all(4.0),
                child: TextField(
                  controller: descriptionTextController,
                  decoration: new InputDecoration.collapsed(
                      hintText:
                          'Game description, ex: An open world game developed by Rockstar studio...'),
                  minLines: 1,
                  maxLines: 5,
                  autocorrect: true,
                  autofocus: true,
                ),
              ),
              Divider(
                height: .5,
              ),
              Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: DropDownField(
                    hintText: 'Game genre',
                    items: Constants.genres,
                    controller: genreTextController,
                    required: true,
                    value: genreTextController.text,
                  )),
              Divider(
                height: .5,
              ),
              _image != null ? Image.file(_image) : Container(),
              Container(
                  margin: EdgeInsets.symmetric(horizontal: 10),
                  child: RaisedButton(
                      child: Icon(FontAwesome.getIconData("image")),
                      textColor: Colors.white,
                      color: Colors.blue,
                      onPressed: () async{
                        PermissionsService().requestStoragePermission(
                            onPermissionDenied: () {
                          print('Permission has been denied');
                        });
                        clearVars();
                        _image = await AppUtil.chooseImage();

                      })),
              Container(
                margin: EdgeInsets.symmetric(horizontal: 10),
                child: RaisedButton(
                    child: Text('Publish'),
                    textColor: Colors.white,
                    color: Colors.blue,
                    onPressed: () {
                      uploadGame(
                          fullNameTextController.text,
                          shortNameTextController.text,
                          descriptionTextController.text,
                          genreTextController.text);
                    }),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: Text('New Game'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => pushHomeScreen(context),
        ),
      ),
      body: Stack(
        alignment: Alignment(0, 0),
        children: <Widget>[
          _buildWidget(),
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
}
