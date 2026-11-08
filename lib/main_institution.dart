// Institutional pilot entry point. Authorization comes from the server session.
import 'package:flutter/material.dart';

import 'product/platform_app.dart';

void main() => runApp(const PlatformApp(institutional: true));
