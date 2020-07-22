import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:glitcher/constants/sizes.dart';

class CustomLoader {
  static CustomLoader _customLoader;

  CustomLoader._createObject();

  factory CustomLoader() {
    if (_customLoader != null) {
      return _customLoader;
    } else {
      _customLoader = CustomLoader._createObject();
      return _customLoader;
    }
  }

  //static OverlayEntry _overlayEntry;
  OverlayState _overlayState; //= new OverlayState();
  OverlayEntry _overlayEntry;

  _buildLoader() {
    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Container(
            height: Sizes.fullHeight(context),
            width: Sizes.fullWidth(context),
            child: buildLoader(context));
      },
    );
  }

  showLoader(context) {
    _overlayState = Overlay.of(context);
    _buildLoader();
    _overlayState.insert(_overlayEntry);
  }

  hideLoader() {
    try {
      _overlayEntry?.remove();
      _overlayEntry = null;
    } catch (e) {
      print("Exception:: $e");
    }
  }

  buildLoader(BuildContext context, {height = 100.0, width = 100.0}) {
    return Center(
        child: Image.asset(
          'assets/images/glitcher_loader.gif',
          height: height,
          width: width,
        ));
  }
}

class CustomScreenLoader extends StatelessWidget {
  final Color backgroundColor;
  final double height;
  final double width;
  const CustomScreenLoader(
      {Key key,
      this.backgroundColor = const Color(0xfff8f8f8),
      this.height = 200,
      this.width = 200})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Container(
        height: height,
        width: height,
        alignment: Alignment.center,
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(10))),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Platform.isIOS
                  ? CupertinoActivityIndicator(
                      radius: 35,
                    )
                  : CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
              Image.asset(
                'assets/images/glitcher_loader.gif',
                height: 200,
                width: 200,
              )
            ],
          ),
        ),
      ),
    );
  }
}
