import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/map_style.dart';

class MapStyleNotifier extends Notifier<MapStyle> {
  @override
  MapStyle build() {
    return MapStyle.standard;
  }

  void setStyle(MapStyle style) {
    state = style;
  }
}

final mapStyleProvider =
    NotifierProvider<MapStyleNotifier, MapStyle>(
  MapStyleNotifier.new,
);