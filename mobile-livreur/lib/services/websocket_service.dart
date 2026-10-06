import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:mobile_core/mobile_core.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final String userId;
  final String userType;
  final String token;
  
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool _isConnected = false;
  Timer? _reconnectTimer;

  WebSocketService({required this.userId, required this.userType, required this.token}) {
    _connect();
  }

  void _connect() {
    if (_isConnected) return;
    
    // Sécurité : le token passe par le SOUS-PROTOCOLE WS (["bearer", token]),
    // plus dans l'URL — évite qu'il finisse dans les logs serveur/proxy.
    final wsUrl = '${AppConstants.wsUrl}/$userId/$userType';
    debugPrint('WS: Tentative de connexion a $wsUrl');

    try {
      _channel = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['bearer', token],
      );

      _channel!.ready.then((_) {
        _isConnected = true;
        debugPrint('WS: Connecte !');
      }).catchError((error) {
        debugPrint('WS: Echec handshake : $error');
        _isConnected = false;
        _scheduleReconnect();
      });

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            _messageController.add(data);
            debugPrint('WS: Message recu type=${data['type']}');
          } catch (e) {
            debugPrint('WS: Erreur decodage message: $e');
          }
        },
        onDone: () {
          debugPrint('WS: Connexion terminee.');
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('WS: Erreur de connexion : $error');
          _isConnected = false;
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('WS: Exception a la connexion : $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    debugPrint('WS: Tentative de reconnexion dans ${AppConstants.wsReconnectDelay.inSeconds} secondes');
    _reconnectTimer = Timer(AppConstants.wsReconnectDelay, _connect);
  }

  /// Reconnexion immédiate — annule le timer en attente et force une nouvelle tentative.
  /// À appeler quand l'app revient au premier plan.
  void forceReconnect() {
    _reconnectTimer?.cancel();
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
    _connect();
  }

  void disconnect() {
    debugPrint('WS: Deconnexion forcee');
    _reconnectTimer?.cancel();
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
    _messageController.close();
  }
}
