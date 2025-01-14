import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'mime_type_resolver.dart';

///This class allows you to create a simple server on `http://localhost:[port]/` in order to be able to load your assets file on a server. The default [port] value is `8080`.
class InAppLocalhostServer {
  bool _started = false;
  HttpServer? _server;
  String _scheme = 'http';
  String _host = 'localhost';
  int _port = 8080;

  InAppLocalhostServer(
      {String scheme = 'http', String host = 'localhost', int port = 8080}) {
    this._scheme = scheme;
    this._host = host;
    this._port = port;
  }

  ///Starts the server on `http://localhost:[port]/`.
  ///
  ///**NOTE for iOS**: For the iOS Platform, you need to add the `NSAllowsLocalNetworking` key with `true` in the `Info.plist` file (See [ATS Configuration Basics]($_schemes://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/uid/TP40009251-SW35)):
  ///```xml
  ///<key>NSAppTransportSecurity</key>
  ///<dict>
  ///    <key>NSAllowsLocalNetworking</key>
  ///    <true/>
  ///</dict>
  ///```
  ///The `NSAllowsLocalNetworking` key is available since **iOS 10**.
  Future<void> start() async {
    if (this._started) {
      throw Exception('Server already started on $_scheme://$_host:$_port');
    }
    this._started = true;

    var completer = Completer();

    runZonedGuarded(() {
      HttpServer.bind('127.0.0.1', _port).then((server) {
        print('Server running on $_scheme://$_host:' + _port.toString());

        this._server = server;

        server.listen((HttpRequest request) async {
          Uint8List body = Uint8List(0);

          var path = request.requestedUri.path;
          path = (path.startsWith('/')) ? path.substring(1) : path;
          path += (path.endsWith('/')) ? 'index.html' : '';

          try {
            body = (await rootBundle.load(path)).buffer.asUint8List();
          } catch (e) {
            print(e.toString());
            request.response.close();
            return;
          }

          var contentType = ['text', 'html'];
          if (!request.requestedUri.path.endsWith('/') &&
              request.requestedUri.pathSegments.isNotEmpty) {
            var mimeType = MimeTypeResolver.lookup(request.requestedUri.path);
            if (mimeType != null) {
              contentType = mimeType.split('/');
            }
          }

          request.response.headers.contentType =
              ContentType(contentType[0], contentType[1], charset: 'utf-8');
          request.response.add(body);
          request.response.close();
        });

        completer.complete();
      });
    }, (e, stackTrace) => print('Error: $e $stackTrace'));

    return completer.future;
  }

  ///Closes the server.
  Future<void> close() async {
    if (this._server == null) {
      return;
    }
    await this._server!.close(force: true);
    print('Server running on $_scheme://$_host:$_port closed');
    this._started = false;
    this._server = null;
  }

  ///Indicates if the server is running or not.
  bool isRunning() {
    return this._server != null;
  }
}
