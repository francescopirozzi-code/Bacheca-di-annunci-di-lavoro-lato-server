import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'storage.dart';

const _jsonHeaders = {'Content-Type': 'application/json'};

void registerAnnunciRoutes(
    Router router,
    JsonStorage annunciStorage,
    JsonStorage candidatureStorage,
    ) {
  // R5 - Elenco pubblico di tutti gli annunci dal più recente
  router.get('/api/annunci', (Request request) async {
    final annunci = await annunciStorage.readAll();
    return Response.ok(
      jsonEncode(annunci.reversed.toList()),
      headers: _jsonHeaders,
    );
  });

  // R5 - Dettaglio singolo annuncio
  router.get('/api/annunci/<id>', (Request request, String id) async {
    final annunci = await annunciStorage.readAll();
    final trovato = annunci.where((a) => a['id'] == id);

    if (trovato.isEmpty) {
      return Response(404,
          body: jsonEncode({'errore': 'Annuncio non trovato'}),
          headers: _jsonHeaders);
    }

    return Response.ok(jsonEncode(trovato.first), headers: _jsonHeaders);
  });

  // R7 - Elenco annunci pubblicati da una specifica azienda
  router.get('/api/aziende/<aziendaId>/annunci',
          (Request request, String aziendaId) async {
        final annunci = await annunciStorage.readAll();
        final mieiAnnunci = annunci
            .where((a) => a['aziendaId'] == aziendaId)
            .toList()
            .reversed
            .toList();

        return Response.ok(jsonEncode(mieiAnnunci), headers: _jsonHeaders);
      });

  // R4 - Pubblicazione nuovo annuncio da parte di un'azienda
  router.post('/api/annunci', (Request request) async {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final titolo = (body['titolo'] ?? '').toString().trim();
    final descrizione = (body['descrizione'] ?? '').toString().trim();
    final aziendaId = (body['aziendaId'] ?? '').toString().trim();
    final nomeAzienda = (body['nomeAzienda'] ?? '').toString().trim();

    if (titolo.isEmpty || descrizione.isEmpty || aziendaId.isEmpty) {
      return Response(400,
          body: jsonEncode({'errore': 'Titolo, descrizione e azienda sono obbligatori'}),
          headers: _jsonHeaders);
    }

    final annunci = await annunciStorage.readAll();
    final nuovoAnnuncio = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'titolo': titolo,
      'descrizione': descrizione,
      'aziendaId': aziendaId,
      'nomeAzienda': nomeAzienda,
      'dataPubblicazione': DateTime.now().toIso8601String(),
    };

    annunci.add(nuovoAnnuncio);
    await annunciStorage.writeAll(annunci);

    return Response(201,
        body: jsonEncode(nuovoAnnuncio), headers: _jsonHeaders);
  });

  // Eliminazione di un annuncio
  router.delete('/api/annunci/<id>', (Request request, String id) async {
    final annunci = await annunciStorage.readAll();
    final countPrima = annunci.length;
    annunci.removeWhere((a) => a['id'] == id);

    if (annunci.length == countPrima) {
      return Response(404,
          body: jsonEncode({'errore': 'Annuncio non trovato'}),
          headers: _jsonHeaders);
    }

    await annunciStorage.writeAll(annunci);

    // Rimuove eventuali candidature collegate e i rispettivi file PDF
    final candidature = await candidatureStorage.readAll();
    final daRimuovere =
    candidature.where((c) => c['annuncioId'] == id).toList();
    for (final c in daRimuovere) {
      final fileSalvato = c['fileSalvato'];
      if (fileSalvato != null && fileSalvato.toString().isNotEmpty) {
        final pdfFile = File('uploads/$fileSalvato');
        if (await pdfFile.exists()) {
          await pdfFile.delete();
        }
      }
    }
    candidature.removeWhere((c) => c['annuncioId'] == id);
    await candidatureStorage.writeAll(candidature);

    return Response.ok(
      jsonEncode({'messaggio': 'Annuncio eliminato con successo'}),
      headers: _jsonHeaders,
    );
  });
}