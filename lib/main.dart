import 'dart:async'; // 非同期処理(async/await)
import 'dart:io'; // ファイルの入出力

import 'package:camera/camera.dart'; // カメラモジュール
import 'package:flutter/material.dart'; // マテリアルデザイン
import 'package:path_provider/path_provider.dart'; // ファイルパスモジュール
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

    if(!await SimplePermissions.checkPermission(Permission.WriteExternalStorage)){
      SimplePermissions.requestPermission(Permission.WriteExternalStorage);
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

  // 画像保存処理
  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      return null;
    }

    final Directory extDir = await getExternalStorageDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      return null;
    }

    await controller.takePicture(filePath);
    return filePath;
  }
}