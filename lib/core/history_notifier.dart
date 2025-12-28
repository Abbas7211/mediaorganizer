import '../hive/boxes.dart';
import 'package:flutter/foundation.dart'; // For ValueNotifier

class HistoryNotifier {
  static final HistoryNotifier I = HistoryNotifier._();
  HistoryNotifier._(); //._ To prevent it from anywhere else / (Private Notifier)

  final ValueNotifier<int> revision = ValueNotifier<int>(0); // When the integer changes, anything listening to it rebuilds.

  // Read history from Hive
  List<String> readFromHive() {
    final stored = historyBox.get('entries');
    if (stored is List) {
      return stored.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    } //map converts element to string //where removes empty strings like //toList returns a real Dart list.
    return <String>[]; //return empty if nothing
  }

  //Write history to Hive
  Future<void> writeToHive(List<String> history) async {
    await historyBox.put('entries', List<String>.from(history)); //Stores the list under entries
    bump(); //tell listeners “something changed”
  }

  void bump() => revision.value++; //Increase revision number by 1 so triggers rebuilds
}
