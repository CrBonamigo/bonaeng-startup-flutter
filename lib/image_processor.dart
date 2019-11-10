import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'detect.dart';
import 'authentication.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart';

class ImageProcessor extends StatefulWidget {
  final File _imageFile;
  final Auth auth;
  ImageProcessor(this._imageFile, this.auth);

  @override
  _ImageProcessorState createState() => _ImageProcessorState();
}

class _ImageProcessorState extends State<ImageProcessor> {
  File _imageFile;
  String _detectionResult = "";
  FirebaseStorage _storage = FirebaseStorage(storageBucket: "gs://startup-255001.appspot.com");

  void initState() {
    // TODO: implement initState
    super.initState();
    setState(() {
      _imageFile = widget._imageFile;
    });
  }

  /// Cropper plugin
  Future<void> _cropImage() async {
    File cropped = await ImageCropper.cropImage(
        sourcePath: _imageFile.path,
        // ratioX: 1.0,
        // ratioY: 1.0,
        // maxWidth: 512,
        // maxHeight: 512,
        toolbarColor: Colors.purple,
        toolbarWidgetColor: Colors.white,
        toolbarTitle: 'Crop It');

    setState(() {
      _imageFile = cropped ?? _imageFile;
    });
  }

  /// Select an image via gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    File selected = await ImagePicker.pickImage(source: source);
    if (selected != null) {
      setState(() {
        _imageFile = selected;
      });
    }
  }

  /// Remove image
  void _clear() {
    // setState(() => _imageFile = null);
    _pickImage(ImageSource.camera);
  }

  Future<String> _detectImage(File img) async{
    print("Send file");
    final String apiEndpoint = "http://startup-bonaeng.herokuapp.com/uploaded";
    //final String apiEndpoint = "http://10.0.2.2:5000/teste";
    FormData formData = new FormData();
    formData.add("photo", UploadFileInfo(_imageFile,basename(_imageFile.path)));
    formData.add("source", "app");

    Response<dynamic> res = await Dio().post(apiEndpoint, data: formData, options: Options(method: 'POST', responseType: ResponseType.json));
    String man = res.data['predictions']['man'].toString();
    String woman = res.data['predictions']['woman'].toString();
    // return "Calcium Deficiency";
    return "People detected: \nMan: " + man + ", Woman: " + woman;
  }

  Future<String> _uploadImage(File img) async{
    String filepath = "face_images/${DateTime.now()}.jpg";
    StorageReference ref = _storage.ref().child(filepath);
    StorageUploadTask uploadTask = ref.putFile(_imageFile);

    String downloadUrl = await (await  uploadTask.onComplete).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Image Processor"),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: <Widget>[
          if (_imageFile != null) ...[
            Image.file(_imageFile),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                FlatButton(
                  child: Icon(Icons.cloud_upload),
                  onPressed: () async {
                    String resultTemp = await _detectImage(_imageFile);
                    //String resultTemp = "teste";
                    String imagePath = await _uploadImage(_imageFile);
                    Timestamp date = Timestamp.fromDate(DateTime.now());
                    FirebaseUser user = await widget.auth.getCurrentUser();

                    setState(() {
                     _detectionResult = resultTemp; 
                    });

                    Firestore.instance.collection("history").add({
                      "date": date,
                      "detectionResult":resultTemp,
                      "imagePath":imagePath,
                      "userID": user.uid
                    });
                  },
                ),
                FlatButton(
                  child: Icon(Icons.crop),
                  onPressed: _cropImage,
                ),
                FlatButton(
                  child: Icon(Icons.refresh),
                  onPressed: _clear,
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.only(top: 30.0),
              child: Center(
                child: Text(
                  _detectionResult,
                  style: TextStyle(fontSize: 20.0),
                ),
              ),
            ),
            // Uploader(file: _imageFile)
          ]
        ],
      ),
    );
  }
}
