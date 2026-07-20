import 'package:flutter/material.dart';

import 'app/app.dart';
import 'services/mock_app_service.dart';

void main() {
  runApp(BAPlannerApp(service: MockAppService()));
}
