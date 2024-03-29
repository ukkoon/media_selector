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
      {String? titleText = '',
      String? completeText = 'done',
      String? albumSelectText = '',
      int? crossAxisCount = 4,
      int? maxLength = 2,
      double? aspectRatio = 1.0 / 1.91,
      double? previewHeight = 300,
      double? previewShowingRatio = 1 / 3,
      CropShape? shape: CropShape.rectangle,
      Color? backgroundColor = Colors.grey,
      Color? tagColor = Colors.yellow,
      Color? tagTextColor = Colors.black,
      Color? textColor = Colors.white,
      Widget? loadingWidget = const Center(
        child: CircularProgressIndicator(),
      ),
      Widget? actionLoadingWidget = const Center(
        child: CircularProgressIndicator(),
      ),
      }) async {
    assert(maxLength! > 0);

    return await Navigator.of(context, rootNavigator: true).push(generateRoute(
        titleText,
        completeText,
        albumSelectText,
        crossAxisCount,
        maxLength,
        aspectRatio,
        previewHeight,
        previewShowingRatio,
        shape,
        backgroundColor,
        tagColor,
        tagTextColor,
        textColor,
        loadingWidget,
        actionLoadingWidget
        ));
  }

  static Route<List<Uint8List>> generateRoute(
      titleText,
      completeText,
      albumSelectText,
      crossAxisCount,
      maxLength,
      aspectRatio,
      previewHeight,
      previewShowingRatio,
      shape,
      backgroundColor,
      tagColor,
      tagTextColor,
      textColor,
      loadingWidget,
      actionLoadingWidget) {
    return MaterialPageRoute(builder: (BuildContext context) {
      return _SelectMediaPage(
        titleText,
        completeText,
        albumSelectText,
        crossAxisCount,
        maxLength,
        aspectRatio,
        previewHeight,
        previewShowingRatio,
        shape,
        backgroundColor,
        tagColor,
        tagTextColor,
        textColor,
        loadingWidget,
        actionLoadingWidget,
        key: UniqueKey(),
      );
    });
  }
}

class _SelectMediaPage extends StatefulWidget {
  const _SelectMediaPage(
      this.titleText,
      this.completeText,
      this.albumSelectText,
      this.crossAxisCount,
      this.maxLength,
      this.aspectRatio,
      this.previewHeight,
      this.previewShowingRatio,
      this.shape,
      this.backgroundColor,
      this.tagColor,
      this.tagTextColor,
      this.textColor,
      this.loadingWidget,
      this.actionLoadingWidget,
      {Key? key})
      : super(key: key);

  final String titleText, completeText, albumSelectText;
  final int crossAxisCount, maxLength;
  final double aspectRatio, previewHeight, previewShowingRatio;
  final CropShape shape;

  final Color backgroundColor, tagColor, textColor, tagTextColor;
  final Widget loadingWidget, actionLoadingWidget;

  @override
  __SelectMediaPageState createState() => __SelectMediaPageState();
}

class __SelectMediaPageState extends State<_SelectMediaPage> {
  late ScrollController controller;
  late ScrollController gridCtrl;
  late List<AssetPathEntity> albums;
  late BuildContext providerCtx;
  late Future<InitData> _data;
  bool canLoad = true;
  bool isLoading = false;

  late double previewHideRatio;
  @override
  void initState() {
    super.initState();
    _data = fetchData();
    previewHideRatio = 1 - widget.previewShowingRatio;
    controller = ScrollController(initialScrollOffset: 0);
    gridCtrl = ScrollController(initialScrollOffset: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: SafeArea(
        child: Stack(
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
                            primary: false,
                            physics: const NeverScrollableScrollPhysics(),
                            slivers: [
                              SliverAppBar(
                                backgroundColor: widget.backgroundColor,
                                foregroundColor: widget.textColor,
                                elevation: 0,
                                title: Text(
                                  widget.titleText,
                                  style: const TextStyle(fontSize: 17),
                                ),
                                actions: [buildActionButton()],
                                pinned: true,
                                snap: true,
                                floating: true,
                              ),
                              if(context.watch<Album>().inited)
                              SliverAppBar(
                                pinned: false,
                                leading: Container(),
                                snap: true,
                                floating: true,
                                backgroundColor: Colors.black,
                                collapsedHeight: widget.previewHeight,
                                flexibleSpace: preview(),
                              ),
                              SliverAppBar(
                                backgroundColor: widget.backgroundColor,
                                elevation: 0,
                                title: header(),
                                centerTitle: false,
                                automaticallyImplyLeading: false,
                                titleSpacing: 0,
                                pinned: true,
                              ),                              
                              SliverFillRemaining(
                                child: medias(),
                              )
                            ],
                          );
                        },
                      )
                    : Center(
                        child: widget.loadingWidget,
                      )),
          ],
        ),
      ),
    );
  }

  buildActionButton() {
    if (providerCtx
        .watch<Album>()
        .selectedMedias
        .every((e) => e.completer!.isCompleted || isLoading)) {
      return GestureDetector(
        onTap: () => tapComplete(),
        child: Container(
          padding: const EdgeInsets.only(right: 15),
          alignment: Alignment.center,
          child: Text(
            widget.completeText,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.only(right: 15),
      child: widget.actionLoadingWidget,
    );
  }

  preview() {
    List<Media> mediasCopy = List.from(providerCtx.read<Album>().selectedMedias);
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
    return GestureDetector(
        behavior: HitTestBehavior.translucent,
        child: Padding(
          padding: const EdgeInsets.all(
            15,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                providerCtx.read<Album>().currentAlbum.name,
                style: TextStyle(color: widget.textColor, fontSize: 15),
              ),
              const SizedBox(
                width: 15,
              ),
              Transform.rotate(
                angle: pi / 2,
                child: Icon(
                  Icons.navigate_next,
                  size: 18,
                  color: widget.textColor,
                ),
              )
            ],
          ),
        ),
        onTap: () async {
          var result = await Navigator.of(context, rootNavigator: true)
              .push(MaterialPageRoute(builder: (context) {
            return Scaffold(
              backgroundColor: widget.backgroundColor,
              body: SafeArea(
                child: CustomScrollView(slivers: [
                  SliverAppBar(
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      color: widget.textColor,
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    backgroundColor: widget.backgroundColor,
                    foregroundColor: widget.textColor,
                    title: Text(
                      widget.albumSelectText,
                      style: const TextStyle(fontSize: 17),
                    ),
                    pinned: true,
                  ),
                  SliverFillRemaining(
                      child: ListView.separated(
                    padding: const EdgeInsets.all(15),
                    shrinkWrap: true,
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      return InkWell(
                          onTap: () {
                            Navigator.of(context).pop(albums[index]);
                          },
                          child: SizedBox(
                            height: 80,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                FutureBuilder(
                                    future: (() async {
                                      List<AssetEntity> assets =
                                          await albums[index].getAssetListRange(
                                              start: 0, end: 1);
                                      Uint8List thumbnail =
                                          (await assets[0].thumbData)!;
                                      return thumbnail;
                                    })(),
                                    builder: (context, snapshot) =>
                                        snapshot.hasData
                                            ? Image.memory(
                                                snapshot.data as Uint8List,
                                                width: 80,
                                                height: 80,
                                                fit: BoxFit.cover,
                                              )
                                            : Container()),
                                const SizedBox(
                                  width: 15,
                                ),
                                IntrinsicHeight(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        albums[index].name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: widget.textColor),
                                      ),
                                      const SizedBox(
                                        height: 5,
                                      ),
                                      Text(
                                        albums[index].assetCount.toString(),
                                        style: TextStyle(
                                            color: widget.textColor
                                                .withOpacity(0.7)),
                                      )
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ));
                    },
                    separatorBuilder: (context, index) {
                      return const SizedBox(
                        height: 30,
                      );
                    },
                  )),
                ]),
              ),
            );
          }));

          switch (result.runtimeType) {
            case AssetPathEntity:
              var list = await (result as AssetPathEntity)
                  .getAssetListRange(start: 0, end: widget.crossAxisCount * 10);

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
                providerCtx.read<Album>().setCurrentAlbum(result);
                providerCtx.read<Album>().assets = list;
                canLoad = true;
              });
              return;
            default:
              return;
          }
        });
  }

  medias() {
    List<Media> assets = providerCtx.watch<Album>().assets;

    return NotificationListener(
      child: GridView.builder(
          shrinkWrap: true,
          primary: false,
          controller: gridCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: assets.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.crossAxisCount,
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
          if (t.metrics.extentAfter < 300 && canLoad) loadMedias();

          if (t.scrollDelta! > 20.0 && controller.offset == 0) {
            controller.animateTo(widget.previewHeight * previewHideRatio,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut);
          } else if (t.scrollDelta! <= -20 && gridCtrl.offset <= 0) {
            controller.animateTo(0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut);
          } else if (t.scrollDelta! <= -20 && controller.offset == 0) {
            controller.animateTo(widget.previewHeight * previewHideRatio,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut);
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
    int idx =
        providerCtx.watch<Album>().selectedMedias.indexWhere((e) => e == media);

    if (idx != -1) {
      text = (idx + 1).toString();
      color = widget.tagColor;
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
      child: widget.maxLength == 1
          ? Container()
          : Wrap(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  child: Text(
                    widget.maxLength > 1 ? text : "",
                    style: TextStyle(
                        fontSize: 12,
                        color: widget.tagTextColor,
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
    if(!providerCtx.read<Album>().inited){
      providerCtx.read<Album>().inited=true;
    }

    if (providerCtx.read<Album>().selectedMedias.contains(media)) {
      Media selectedMedia = providerCtx.read<Album>().selectedMedia!;
      if (selectedMedia == media) {
        providerCtx.read<Album>().deleteSelectedMedia(media);
      } else {
        providerCtx.read<Album>().setCurrentMedia(media);
        scrolls(media);
      }
    } else {
      if (widget.maxLength > 1 &&
          providerCtx.read<Album>().selectedMedias.length >= widget.maxLength) {
        return;
      }

      if (widget.maxLength == 1) {
        Media? selectedMedia = providerCtx.read<Album>().selectedMedia;
        if (selectedMedia != null) {
          providerCtx.read<Album>().deleteSelectedMedia(selectedMedia);
        }
      }

      Completer completer = Completer();

      media.thumbDataWithSize(4096, 4096).then((value) {
        completer.complete(value);
        providerCtx.read<Album>().notifyListeners();
      });

      //don't worry about await, too fast
      Uint8List thumbdata = (await media.thumbData)!;

      Widget image = Stack(
        children: [
          Image.memory(
            thumbdata,
            fit: BoxFit.cover,
          ),
          FutureBuilder(
              future: completer.future,
              builder: (context, snapshot) => snapshot.hasData
                  ? Image.memory(
                      snapshot.data as Uint8List,
                      fit: BoxFit.cover,
                    )
                  : Container())
        ],
      );

      media.completer = completer;

      media.crop = Crop(
        controller: CropController(aspectRatio: widget.aspectRatio),
        child: image,
        dimColor: Colors.black,
        onChanged: (e) {
          if (controller.offset != 0) {
            controller.animateTo(0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut);
          }
        },
        backgroundColor: Colors.transparent,
        padding: const EdgeInsets.all(0),
        overlay: FittedBox(
          child: Container(
            alignment: Alignment.center,        
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width * 1 / widget.aspectRatio,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                    widget.shape == CropShape.circle ? 1000 : 0),
                border: Border.all(color: Colors.white, width: 1)),
          ),
        ),
      );

      providerCtx.read<Album>().addSelectedMedia(media);
      scrolls(media);
    }
  }

  scrolls(Media media) async {
    double itemheigth =
        MediaQuery.of(context).size.width / widget.crossAxisCount;
    int index = providerCtx.read<Album>().assets.indexOf(media);

    gridCtrl.animateTo(index ~/ widget.crossAxisCount * itemheigth,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

    controller.animateTo(0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  loadMedias() async {
    canLoad = false;
    List<Media> assets = providerCtx.read<Album>().assets;

    var list = await providerCtx.read<Album>().currentAlbum.getAssetListRange(
        start: assets.length, end: assets.length + widget.crossAxisCount * 10);

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
    Map<AssetPathEntity, List<AssetEntity>> albumMap = {};

    List<AssetPathEntity> albums = await PhotoManager.getAssetPathList();

    for (int i = 0; i < albums.length; i++) {
      albumMap.addAll({albums[i]: await albums[i].assetList});
    }

    albums.sort((a, b) {
      if (a.isAll) {
        return -1;
      }
      return 1;
    });

    List<AssetPathEntity> _onlyImageAlbums = [];

    for (int i = 0; i < albums.length; i++) {
      var list = await albums[i]
          .getAssetListRange(start: 0, end: widget.crossAxisCount * 10);

      if (list.isNotEmpty) _onlyImageAlbums.add(albums[i]);
    }

    this.albums = _onlyImageAlbums;

    var list = await albums[0]
        .getAssetListRange(start: 0, end: widget.crossAxisCount * 10);

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
    setState(() {
      isLoading = true;
    });

    try {
      var devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
      List<Media> medias = providerCtx.read<Album>().selectedMedias;
      List<Uint8List> images = [];
      for (int i = 0; i < medias.length; i++) {
        var img =
            await medias[i].crop!.controller.crop(pixelRatio: devicePixelRatio);
        var byteData = await img.toByteData(format: ui.ImageByteFormat.png);
        var buffer = byteData!.buffer.asUint8List();

        images.add(buffer);
      }
      Navigator.of(context).pop(images);
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }
}

class InitData {
  final List<Media> recentPhotos;
  InitData({required this.recentPhotos});
}

class Album extends ChangeNotifier {
  Album(this._assets, this._currentAlbum, this._selectedMedias);

  Media? _selectedMedia;
  AssetPathEntity _currentAlbum;

  bool _inited = false;
  List<Media> _selectedMedias;
  List<Media> _assets;

  List<Media> get selectedMedias => _selectedMedias;

  bool get inited => _inited;
  set inited(value) => _inited = value;

  AssetPathEntity get currentAlbum => _currentAlbum;
  setCurrentAlbum(currentAlbum, {withNotify = true}) {
    if (withNotify) notifyListeners();
    _currentAlbum = currentAlbum;
  }

  deleteSelectedMedia(Media media) {
    _selectedMedias.remove(media);

    if (_selectedMedias.isNotEmpty) {
      _selectedMedia = _selectedMedias.last;
    } else {
      _selectedMedia = null;
    }
    notifyListeners();
  }

  setCurrentMedia(Media media) {
    _selectedMedia = media;
    notifyListeners();
  }

  Media? get selectedMedia => _selectedMedia;

  addSelectedMedia(Media media) {
    _selectedMedias.add(media);
    _selectedMedia = media;
    notifyListeners();
  }

  List<Media> get assets => _assets;

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
  Completer? completer;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Media && other.id == id;
  }
}
