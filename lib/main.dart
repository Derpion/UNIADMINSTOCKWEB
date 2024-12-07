import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:unistock/controllers/menu_controller.dart';
import 'package:unistock/controllers/navigation_controller.dart';
import 'package:unistock/widgets/log_in.dart';

class UserController extends GetxController {
  var documentId = ''.obs;

  void setDocumentId(String id) {
    documentId.value = id;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load();

  await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY'] ?? "",
        projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? "",
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? "",
        appId: dotenv.env['FIREBASE_APP_ID'] ?? "",
        storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? "",
      )
  );

  Get.put(CustomMenuController());
  Get.put(NavigationController());
  Get.put(UserController());

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Admin Dashboard",
      theme: ThemeData(
          scaffoldBackgroundColor: Colors.white,
          textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme)
              .apply(bodyColor: Colors.black),
          pageTransitionsTheme: PageTransitionsTheme(builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder()
          }),
          primaryColor: Colors.blue),
      home: LoginPage(),
    );
  }
}
