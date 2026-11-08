// Synthetic institution environment sharing the consumer demo's database.
import 'package:flutter/material.dart';

import 'product/platform_app.dart';

void main() => runApp(const PlatformApp(demo: true, institutional: true));
