import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';
import 'package:shelf_router/shelf_router.dart';
import 'storage.dart';

const _jsonHeaders = {'Content-Type': 'application/json'};

void registerCandidatureRoutes(
    Router router, JsonStorage candidatureStorage) {
  // R6 - Invio candidatura con dati anagrafici e file PDF
  router.post('/api/annunci/<annuncioId>/candidature',
          (Request request, String annuncioId) async {
        final formDataRequest = request.formData();
        if (formDataRequest == null) {
          return Response(400,
              body: jsonEncode({'errore': 'Richiesta multipart non valida'}),
              headers: _jsonHeaders);
        }

        String nome = '';
        String cognome = '';
        String email = '';
        String? nomeFileOriginale;
        Uint8List? fileBytes;

        await for (final item in formDataRequest.formData) {
          if (item.filename != null && item.filename!.isNotEmpty) {
            nomeFileOriginale = item.filename;
            fileBytes = await item.part.readBytes();
          } else {
            final value = (await item.part.readString()).trim();
            if (item.name == 'nome') nome = value;
            if (item.name == 'cognome') cognome = value;
            if (item.name == 'email') email = value;
          }
        }

        if (nome.isEmpty ||
            cognome.isEmpty ||
            email.isEmpty ||
            fileBytes == null ||
            nomeFileOriginale == null) {
          return Response(400,
              body: jsonEncode({
                'errore': 'Nome, cognome, email e file PDF sono obbligatori'
              }),
              headers: _jsonHeaders);
        }

        // Salva il file PDF nella cartella uploads/
        final safeOriginal =
        nomeFileOriginale.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final fileSalvato =
            '${DateTime.now().millisecondsSinceEpoch}_$safeOriginal';
        final uploadFile = File('uploads/$fileSalvato');
        await uploadFile.parent.create(recursive: true);
        await uploadFile.writeAsBytes(fileBytes);

        // Salva la candidatura in data/candidature.json
        final candidature = await candidatureStorage.readAll();
        final nuovaCandidatura = {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'annuncioId': annuncioId,
          'nome': nome,
          'cognome': cognome,
          'email': email,
          'nomeFileOriginale': nomeFileOriginale,
          'fileSalvato': fileSalvato,
          'dataInvio': DateTime.now().toIso8601String(),
        };

        candidature.add(nuovaCandidatura);
        await candidatureStorage.writeAll(candidature);

        return Response(201,
            body: jsonEncode(nuovaCandidatura), headers: _jsonHeaders);
      });

  // R7 - Elenco candidature ricevute per un annuncio
  router.get('/api/annunci/<annuncioId>/candidature',
          (Request request, String annuncioId) async {
        final candidature = await candidatureStorage.readAll();
        final ricevute = candidature
            .where((c) => c['annuncioId'] == annuncioId)
            .toList()
            .reversed
            .toList();

        return Response.ok(jsonEncode(ricevute), headers: _jsonHeaders);
      });

  // R7 - Download/apertura del curriculum PDF salvato
  router.get('/uploads/<fileName>',
          (Request request, String fileName) async {
        final safeName = File(fileName).uri.pathSegments.last;
        final file = File('uploads/$safeName');

        if (!await file.exists()) {
          return Response(404,
              body: jsonEncode({'errore': 'File curriculum non trovato'}),
              headers: _jsonHeaders);
        }

        final bytes = await file.readAsBytes();
        return Response.ok(
          bytes,
          headers: {
            'Content-Type': 'application/pdf',
            'Content-Disposition': 'inline; filename="$safeName"',
          },
        );
      });
}