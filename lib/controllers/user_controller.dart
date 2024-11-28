import 'package:get/get.dart';

class UserController extends GetxController {
  var documentId = ''.obs;

  void setDocumentId(String id) {
    documentId.value = id;
  }
}
