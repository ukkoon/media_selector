import 'package:flutter/material.dart';
import 'package:media_selector/media_selector.dart';
import 'package:media_selector/selector.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      // theme: ThemeData(
      //   primarySwatch: Colors.blue,
      // ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextButton(
                onPressed: () {
                  MediaSelector.selectMedia(context,
                      maxLength: 2,
                      aspectRatio: 1.0,
                      previewHeight: MediaQuery.of(context).size.height*1/2,
                      shape: CropShape.rectangle,
                      textColor: Colors.white,
                      backgroundColor:Colors.brown,
                      tagColor: Colors.yellow,
                      tagTextColor: Colors.black);
                },
                child: Text('get images'))
          ],
        ),
      ),
    );
  }
}
