import 'dart:async'; // 非同期処理(async/await)
import 'dart:io'; // ファイルの入出力

import 'package:camera/camera.dart'; // カメラモジュール
import 'package:flutter/material.dart'; // マテリアルデザイン
import 'package:path_provider/path_provider.dart'; // ファイルパスモジュール
import 'package:image_picker_saver/image_picker_saver.dart'; // iOSカメラロール用パスモジュール
import 'package:simple_permissions/simple_permissions.dart'; // パーミッションモジュール

List<CameraDescription> cameras; // 使用できるカメラのリスト

// ここから始まる
Future<Null> main() async {
  cameras = await availableCameras();
  runApp(CameraApp());
}

// 親玉のApp
class CameraApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraWidget(),
    );
  }
}

// 親玉の中身
class CameraWidget extends StatefulWidget {
  @override
  _CameraWidgetState createState() {
    return _CameraWidgetState();
  }
}

// 実際はこれがやることやる
class _CameraWidgetState extends State<CameraWidget> {
  CameraController controller;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String timestamp() =>
      DateTime.now().millisecondsSinceEpoch.toString(); // ファイル名にはタイムスタンプ入れる。
  void showInSnackBar(String message) => _scaffoldKey.currentState
      .showSnackBar(SnackBar(content: Text(message))); // SnackBarでメッセージ表示

  @override
  Widget build(BuildContext context) {
    Scaffold sc = Scaffold(
      key: _scaffoldKey,
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              child: Padding(
                padding: const EdgeInsets.all(1.0),
                child: Center(
                  child: _cameraPreviewWidget(), // カメラのプレビューを表示するWidget
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              IconButton(
                // カメラの撮影ボタン
                icon: const Icon(Icons.camera_alt),
                onPressed: controller != null && controller.value.isInitialized
                    ? onTakePictureButtonPressed // 撮影ボタンを押された時にコールバックされる関数
                    : null,
              ),
            ],
          )
        ],
      ),
    );

    // カメラのセットアップ。セットアップが終わったらもう一回buildが走るので、
    // controllerがnullかどうかで処理実施有無を判定。
    if (controller == null) {
      if (cameras.length == 0) {
        throw Exception("使用できるカメラがありません");
      }
      setUpCamera(cameras[0]);
    }
    return sc;
  }

  /// カメラプレビューを表示するWidget
  Widget _cameraPreviewWidget() {
    if (controller == null || !controller.value.isInitialized) {
      // カメラの準備ができるまではテキストを表示
      return const Text('Tap a camera');
    } else {
      // 準備ができたらプレビュー表示
      return AspectRatio(
        aspectRatio: controller.value.aspectRatio,
        child: CameraPreview(controller),
      );
    }
  }

  // カメラを準備する
  void setUpCamera(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller.dispose();
    }
    controller = CameraController(cameraDescription, ResolutionPreset.high);

    // カメラの情報が更新されたら呼ばれるリスナー設定
    controller.addListener(() {
      if (mounted) setState(() {}); // 準備終わったらbuildし直す。
      if (controller.value.hasError) {
        showInSnackBar('Camera error ${controller.value.errorDescription}');
      }
    });

    await controller.initialize();

    // パーミッションの確認・要求
    if (Platform.isAndroid &&
        !await SimplePermissions.checkPermission(Permission.WriteExternalStorage)) {
      SimplePermissions.requestPermission(Permission.WriteExternalStorage);
    } else if (Platform.isIOS &&
        !await SimplePermissions.checkPermission(Permission.PhotoLibrary)) {
      SimplePermissions.requestPermission(Permission.PhotoLibrary);
    }

    if (mounted) {
      setState(() {});
    }
  }

  // 撮影ボタンが押されたら撮影して、画像を保存する
  void onTakePictureButtonPressed() {
    takePicture().then((String filePath) {
      if (mounted) {
        setState(() {});
        if (filePath != null) showInSnackBar('Picture saved to $filePath');
      }
    });
  }

  // 画像撮影・保存処理
  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      return null;
    }

    Directory dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory(); // 外部ストレージに保存
    } else if (Platform.isIOS) {
      dir = await getTemporaryDirectory(); // 一時ディレクトリに保存
    } else {
      return null;
    }

    final String dirPath = '${dir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      return null;
    }

    await controller.takePicture(filePath);

    // filePathに保存されたデータをiOSならPhotoLibrary領域にコピーする
    if (Platform.isIOS) {
      String tmpPath = filePath;
      var savedFile = File.fromUri(Uri.file(tmpPath));
      filePath = await ImagePickerSaver.saveFile(
          fileData: savedFile.readAsBytesSync());
    }

    return filePath;
  }
}
