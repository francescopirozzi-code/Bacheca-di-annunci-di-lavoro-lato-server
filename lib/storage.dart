import 'dart:convert';
import 'dart:io';

typedef JsonMap = Map<String, dynamic>;

class JsonStorage {
  final File file;

  JsonStorage(String path) : file = File(path);

  // Legge tutti gli elementi dal file JSON
  Future<List<JsonMap>> readAll() async {
    if (!await file.exists()) {
      return [];
    }
    final content = await file.readAsString();
    if (content.trim().isEmpty) {
      return [];
    }
    final List<dynamic> decoded = jsonDecode(content);
    return decoded.cast<JsonMap>();
  }

  // Salva l'intera lista aggiornata nel file JSON
  Future<void> writeAll(List<JsonMap> items) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(items));
  }
}