import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'storage.dart';

const _jsonHeaders = {'Content-Type': 'application/json'};

void registerAuthRoutes(Router router, JsonStorage aziendeStorage) {
  // R1 - Registrazione azienda
  router.post('/api/auth/register', (Request request) async {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final nomeAzienda = (body['nomeAzienda'] ?? '').toString().trim();
    final email = (body['email'] ?? '').toString().trim().toLowerCase();
    final password = (body['password'] ?? '').toString().trim();

    if (nomeAzienda.isEmpty || email.isEmpty || password.isEmpty) {
      return Response(400,
          body: jsonEncode({'errore': 'Tutti i campi sono obbligatori'}),
          headers: _jsonHeaders);
    }

    final aziende = await aziendeStorage.readAll();
    final esisteGia = aziende.any((a) => a['email'] == email);
    if (esisteGia) {
      return Response(409,
          body: jsonEncode({'errore': 'Email già registrata'}),
          headers: _jsonHeaders);
    }

    final nuovaAzienda = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'nomeAzienda': nomeAzienda,
      'email': email,
      'password': password,
    };

    aziende.add(nuovaAzienda);
    await aziendeStorage.writeAll(aziende);

    return Response(201,
        body: jsonEncode({
          'id': nuovaAzienda['id'],
          'nomeAzienda': nuovaAzienda['nomeAzienda'],
          'email': nuovaAzienda['email'],
        }),
        headers: _jsonHeaders);
  });

  // R2 - Login azienda
  router.post('/api/auth/login', (Request request) async {
    final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    final email = (body['email'] ?? '').toString().trim().toLowerCase();
    final password = (body['password'] ?? '').toString().trim();

    final aziende = await aziendeStorage.readAll();
    final trovata = aziende.where(
          (a) => a['email'] == email && a['password'] == password,
    );

    if (trovata.isEmpty) {
      return Response(401,
          body: jsonEncode({'errore': 'Email o password non corretti'}),
          headers: _jsonHeaders);
    }

    final azienda = trovata.first;
    return Response.ok(
      jsonEncode({
        'id': azienda['id'],
        'nomeAzienda': azienda['nomeAzienda'],
        'email': azienda['email'],
      }),
      headers: _jsonHeaders,
    );
  });
}