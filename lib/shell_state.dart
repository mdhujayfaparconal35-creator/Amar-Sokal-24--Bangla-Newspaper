import 'package:flutter/material.dart';

/// কোনো পেজ অন্য পেজের নিচে ঢাকা পড়লে (যেমন রিলস ট্যাবের ওপর রিওয়ার্ড পেজ খুললে) জানার জন্য
final RouteObserver<ModalRoute<void>> appRouteObserver = RouteObserver<ModalRoute<void>>();
