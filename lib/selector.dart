import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crop/crop.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

enum CropShape { rectangle, circle }

class MediaSelector {
  static Future<List<Uint8List>?> selectMedia(context,
      {int? crossAxisCount = 3,
      int? maxLength = 2,
      double? aspectRatio = 1.0 / 1.91,
      CropShape? shape: CropShape.rectangle,
      Color? backgroundColor = Colors.grey,
      Color? tagColor = Colors.yellow,
      Color? tagTextColor = Colors.black,
      Color? textColor = Colors.white,
      Widget? loadingWidget = const Center(
        child: CircularProgressIndicator(),
      )}) async {
    assert(maxLength! > 0);

    return await Navigator.of(context, rootNavigator: true).push(generateRoute(
        crossAxisCount,
        maxLength,
        aspectRatio,
        shape,
        backgroundColor,
        tagColor,
        tagTextColor,
        textColor,
        loadingWidget));
  }

  static Route<List<Uint8List>> generateRoute(
      crossAxisCount,
      maxLength,
      aspectRatio,
      shape,
      backgroundColor,
      tagColor,
      tagTextColor,
      textColor,
      loadingWidget) {
    return MaterialPageRoute(builder: (BuildContext context) {
      return _SelectMediaPage(
        crossAxisCount,
        maxLength,
        aspectRatio,
        shape,
        backgroundColor,
        tagColor,
        tagTextColor,
        textColor,
        loadingWidget,
        key: UniqueKey(),
      );
    });
  }
}

class _SelectMediaPage extends StatefulWidget {
  const _SelectMediaPage(
      this.crossAxisCount,
      this.maxLength,
      this.aspectRatio,
      this.shape,
      this.backgroundColor,
      this.tagColor,
      this.tagTextColor,
      this.textColor,
      this.loadingWidget,
      {Key? key})
      : super(key: key);

  final int crossAxisCount, maxLength;
  final double aspectRatio;
  final CropShape shape;

  final Color backgroundColor, tagColor, textColor, tagTextColor;
  final Widget loadingWidget;

  @override
  __SelectMediaPageState createState() => __SelectMediaPageState(
      this.crossAxisCount,
      this.maxLength,
      this.aspectRatio,
      this.shape,
      this.backgroundColor,
      this.tagColor,
      this.tagTextColor,
      this.textColor,
      this.loadingWidget);
}

class __SelectMediaPageState extends State<_SelectMediaPage> {
  __SelectMediaPageState(
      this.crossAxisCount,
      this.maxLength,
      this.aspectRatio,
      this.shape,
      this.backgroundColor,
      this.tagColor,
      this.tagTextColor,
      this.textColor,
      this.loadingWidget);

  final int crossAxisCount, maxLength;
  final double aspectRatio;
  final CropShape shape;

  final Color backgroundColor, tagColor, textColor, tagTextColor;
  final Widget loadingWidget;

  late ScrollController controller;
  late ScrollController gridCtrl;
  late List<AssetPathEntity> albums;
  late BuildContext providerCtx;
  late Future<InitData> _data;
  bool canLoad = true;

  @override
  void initState() {
    super.initState();
    _data = fetchData();

    controller = ScrollController();
    gridCtrl = ScrollController();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: Stack(
          children: [
            FutureBuilder(
                future: _data,
                builder: (context, snapshot) => snapshot.hasData
                    ? ChangeNotifierProvider(
                        create: (context) => Album(
                            (snapshot.data as InitData).recentPhotos,
                            albums[0], []),
                        builder: (context, child) {
                          providerCtx = context;
                          return CustomScrollView(
                            controller: controller,
                            slivers: [
                              SliverAppBar(
                                backgroundColor: backgroundColor,
                                foregroundColor: textColor,
                                // pinned: false,
                                // stretch: false,
                                title: Text(
                                  '$maxLength개 선택 가능',
                                  style: TextStyle(fontSize: 17),
                                ),
                                actions: [
                                  GestureDetector(
                                    onTap: () => tapComplete(),
                                    child: Container(
                                      padding: EdgeInsets.only(right: 15),
                                      alignment: Alignment.center,
                                      child: Text('완료'),
                                    ),
                                  )
                                ],
                                snap: true,
                                floating: true,
                              ),
                              SliverAppBar(
                                pinned: false,
                                leading: Container(),
                                snap: true,
                                floating: true,
                                backgroundColor: Colors.black,
                                collapsedHeight:
                                    MediaQuery.of(context).size.height *
                                        (2 / 3),
                                flexibleSpace: preview(),
                              ),
                              SliverAppBar(
                                backgroundColor: backgroundColor,
                                title: header(),
                                automaticallyImplyLeading: false,
                                titleSpacing: 0,
                                pinned: false,
                              ),
                              SliverFillRemaining(
                                child: medias(),
                              )
                            ],
                          );
                        },
                      )
                    : loadingWidget),
          ],
        ),
      ),
    );
  }

  preview() {
    List<Media> mediasCopy =
        List.from(providerCtx.read<Album>().selectedMedias);
    Media? selectedMedia = providerCtx.watch<Album>().selectedMedia;
    mediasCopy.sort((a, b) => a == selectedMedia ? 1 : -1);
    if (providerCtx.watch<Album>().selectedMedias.isNotEmpty) {
      return Stack(
        children: [
          ...mediasCopy.map((e) => Opacity(
              key: Key(e.id),
              opacity: e == selectedMedia ? 1 : 0.001,
              child: e.crop!))
        ],
      );
    } else {
      return Container(
        color: Colors.black,
      );
    }
  }

  header() {
    return Align(
      alignment: Alignment.centerLeft,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: providerCtx.read<Album>().currentAlbum.id,
          dropdownColor: backgroundColor,
          items: [
            ...albums.map((album) {
              return DropdownMenuItem<String>(
                value: album.id,
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 10),
                  child: Text(
                    album.name,
                    style: TextStyle(color: textColor),
                  ),
                ),
              );
            })
          ],
          icon: Transform.rotate(
            angle: pi / 2,
            child: Icon(
              Icons.navigate_next,
              size: 18,
              color: textColor,
            ),
          ),
          onChanged: (String? albumId) async {
            AssetPathEntity album = albums.firstWhere((e) => e.id == albumId);

            if (albumId == providerCtx.read<Album>().currentAlbum.id) {
              return;
            } else {
              var list = await album.getAssetListRange(
                  start: 0, end: crossAxisCount * 10);

              list = list
                  .map((e) => Media(
                        e.id,
                        e.typeInt,
                        e.width,
                        e.height,
                        e.thumbDataWithSize(200, 200),
                      ))
                  .toList();

              setState(() {
                providerCtx.read<Album>().setCurrentAlbum(album);
                providerCtx.read<Album>().assets = list;
                canLoad = true;
              });
            }
          },
        ),
      ),
    );
  }

  medias() {
    List<Media> assets = providerCtx.watch<Album>().assets;

    return NotificationListener(
      child: GridView.builder(
          shrinkWrap: true,
          controller: gridCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: assets.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
          ),
          itemBuilder: (context, index) {
            return FutureBuilder(
                future: assets[index].thumbdata,
                builder: (context, snapshot) => snapshot.hasData
                    ? InkWell(
                        onTap: () => tapMedia(assets[index]),
                        child: Stack(
                          children: [
                            SizedBox(
                              width: 100,
                              height: 100,
                              child: Image.memory(
                                snapshot.data as Uint8List,
                                key: Key(assets[index].id),
                                fit: BoxFit.cover,
                              ),
                            ),
                            buildTag(assets[index])
                          ],
                        ),
                      )
                    : Container());
          }),
      onNotification: (t) {
        if (t is ScrollUpdateNotification) {
          if (t.metrics.extentAfter < 200 && canLoad) loadMedias();

          if (t.scrollDelta! > 10.0 && controller.offset == 0) {
            controller.animateTo(controller.position.maxScrollExtent,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeIn);
          } else if (t.scrollDelta! <= -10 && gridCtrl.offset <= 0) {
            controller.animateTo(0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeIn);
          } else if (t.scrollDelta! <= -10 && controller.offset == 0) {
            controller.animateTo(controller.position.maxScrollExtent,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeIn);
          }
        }
        return true;
      },
    );
  }

  buildTag(Media media) {
    String text = "";
    Color color = Colors.transparent;
    Color backgroundColor = Colors.transparent;
    int idx = providerCtx.watch<Album>().selectedMedias.indexWhere((e) => e == media);

    if (idx != -1) {
      text = (idx + 1).toString();
      color = tagColor;
    }

    if (idx != -1 && media == providerCtx.watch<Album>().selectedMedia) {
      backgroundColor = Colors.black38;
    }

    return Container(
      padding: const EdgeInsets.only(top: 5, right: 5),
      color: backgroundColor,
      alignment: Alignment.topRight,
      height: 100,
      width: 100,
      child: Wrap(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            child: Text(
              maxLength>1?text:"",
              style: TextStyle(
                  fontSize: 12,
                  color: tagTextColor,
                  fontWeight: FontWeight.bold),
            ),
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white)),
          )
        ],
      ),
    );
  }

  tapMedia(Media media) async {
    if (providerCtx.read<Album>().selectedMedias.contains(media)) {
      Media selectedMedia = providerCtx.read<Album>().selectedMedia!;
      if (selectedMedia == media) {
        providerCtx.read<Album>().deleteSelectedMedia(media);
      } else {
        providerCtx.read<Album>().setCurrentMedia(media);
        scrolls(media);
      }
    } else {
      if (maxLength > 1 &&
          providerCtx.read<Album>().selectedMedias.length >= maxLength) {
        return;
      }

      if (maxLength == 1) {
        Media? selectedMedia = providerCtx.read<Album>().selectedMedia;
        if (selectedMedia != null) {
          providerCtx.read<Album>().deleteSelectedMedia(selectedMedia);
        }
      }

      Completer completer = Completer();

      media.thumbDataWithSize(800, 1600).then((value) {
        completer.complete(value);
      });

      //don't worry about await, too fast
      Uint8List thumbdata = (await media.thumbData)!;

      Widget image = FutureBuilder(
        future: completer.future,
        builder: (context, snapshot) => snapshot.hasData
            ? Image.memory(
                snapshot.data as Uint8List,
                fit: BoxFit.cover,
              )
            : Image.memory(
                thumbdata,
                fit: BoxFit.cover,
              ),
      );

      media.crop = Crop(
        controller: CropController(aspectRatio: aspectRatio),
        child: image,
        dimColor: Colors.black,
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.all(0),
        overlay: FittedBox(
          child: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width * 1 / aspectRatio,
            decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(shape == CropShape.circle ? 1000 : 0),
                border: Border.all(color: Colors.white, width: 1)),
          ),
        ),
      );

      providerCtx.read<Album>().addSelectedMedia(media);
      scrolls(media);
    }
  }

  scrolls(Media media) {
    double itemheigth = MediaQuery.of(context).size.width / 4;
    int index = providerCtx.read<Album>().assets.indexOf(media);

    gridCtrl.animateTo(index ~/ 4 * itemheigth,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    controller.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  loadMedias() async {
    canLoad = false;
    List<Media> assets = providerCtx.read<Album>().assets;

    var list = await providerCtx.read<Album>().currentAlbum.getAssetListRange(
        start: assets.length, end: assets.length + crossAxisCount * 10);

    if (list.isNotEmpty) {
      list = list
          .map((e) => Media(
                e.id,
                e.typeInt,
                e.width,
                e.height,
                e.thumbDataWithSize(200, 200),
              ))
          .toList();

      providerCtx.read<Album>().load(list);
      canLoad = true;
    }
  }

  Future<InitData> fetchData() async {
    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList();
    List<AssetPathEntity> _onlyImageAlbums = [];

    for (int i = 0; i < albums.length; i++) {
      var list =
          await albums[i].getAssetListRange(start: 0, end: crossAxisCount * 10);

      if (list.isNotEmpty) _onlyImageAlbums.add(albums[i]);
    }

    this.albums = _onlyImageAlbums;

    var list = await this
        .albums[0]
        .getAssetListRange(start: 0, end: crossAxisCount * 10);

    return InitData(
      recentPhotos: list
          .map(
            (e) => Media(
              e.id,
              e.typeInt,
              e.width,
              e.height,
              e.thumbDataWithSize(200, 200),
            ),
          )
          .toList(),
    );
  }

  tapComplete() async {
    List<Media> medias = providerCtx.read<Album>().selectedMedias;
    List<Uint8List> images = [];
    for (int i = 0; i < medias.length; i++) {
      var img = await medias[i].crop!.controller.crop();
      var byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      var buffer = byteData!.buffer.asUint8List();

      images.add(buffer);
    }

    Navigator.of(context).pop(images);
  }
}

class InitData {
  final List<Media> recentPhotos;
  InitData({required this.recentPhotos});
}

class Album extends ChangeNotifier {
  Album(this._assets, this._currentAlbum, this._selectedMedias);

  Media? selectedMedia;
  AssetPathEntity _currentAlbum;

  List<Media> _selectedMedias;
  List<Media> _assets;

  List<Media> get selectedMedias => _selectedMedias;

  AssetPathEntity get currentAlbum => _currentAlbum;
  setCurrentAlbum(currentAlbum, {withNotify = true}) {
    if (withNotify) notifyListeners();
    _currentAlbum = currentAlbum;
  }

  deleteSelectedMedia(Media media) {
    _selectedMedias.remove(media);

    if (_selectedMedias.isNotEmpty) {
      selectedMedia = _selectedMedias.last;
    } else {
      selectedMedia = null;
    }
    notifyListeners();
  }

  setCurrentMedia(Media media) {
    selectedMedia = media;
    notifyListeners();
  }

  addSelectedMedia(Media media) {
    _selectedMedias.add(media);
    selectedMedia = media;
    notifyListeners();
  }

  get assets => _assets;

  set assets(assets) => _assets = assets;

  load(assets) {
    _assets.addAll(assets);
    notifyListeners();
  }
}

class Media extends AssetEntity {
  Media(id, typeInt, width, height, this.thumbdata, {this.crop})
      : super(
          id: id,
          typeInt: typeInt,
          width: width,
          height: height,
        );

  Future<Uint8List?> thumbdata;
  Crop? crop;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Media && other.id == id;
  }
}
