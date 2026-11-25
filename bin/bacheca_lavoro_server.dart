import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:bacheca_lavoro_server/storage.dart';
import 'package:bacheca_lavoro_server/auth_routes.dart';
import 'package:bacheca_lavoro_server/annunci_routes.dart';
import 'package:bacheca_lavoro_server/candidature_routes.dart';

void main() async {
  final router = Router();
  final aziendeStorage = JsonStorage('data/aziende.json');
  registerAuthRoutes(router, aziendeStorage);
  final annunciStorage = JsonStorage('data/annunci.json');
  final candidatureStorage = JsonStorage('data/candidature.json');
  registerAnnunciRoutes(router, annunciStorage, candidatureStorage);
  registerCandidatureRoutes(router, candidatureStorage);

  // Prova per verificare che il server sia raggiungibile
  router.get('/api/ping', (Request request) {
    return Response.ok(
      jsonEncode({'status': 'ok', 'messaggio': 'Server Bacheca Lavoro attivo!'}),
      headers: {'Content-Type': 'application/json'},
    );
  });

  // Avvia il server sulla porta 8080
  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router.call);
  final server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
  print('Server in ascolto sulla porta ${server.port}');

  // Indirizzi IP del PC per collegare lo smartphone
  for (var interface in await NetworkInterface.list()) {
    for (var addr in interface.addresses) {
      if (addr.type == InternetAddressType.IPv4) {
        print('Raggiungibile su: http://${addr.address}:${server.port}');
      }
    }
  }
}
