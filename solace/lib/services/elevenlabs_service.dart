import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

    class ElevenLabsService {
      // Replace with your actual backend URL when deployed.
      // For local development, this might be http://10.0.2.2:3000 on Android emulator.
  final String _backendUrl = 'http://192.168.137.140:3000/api/chat/generate-speech';
      final AudioPlayer _audioPlayer = AudioPlayer();

      Future<void> playTextAsSpeech(String text) async {
        try {
          debugPrint('Attempting to generate speech for: $text');
          debugPrint('Backend URL: $_backendUrl');
          
          final response = await http.post(
            Uri.parse(_backendUrl),
            headers: {'Content-Type': 'application/json'},
            body: '{"text": "$text"}',
          );

          debugPrint('Response status: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            // The response body is the raw audio data (bytes).
            final audioBytes = response.bodyBytes;
            debugPrint('Received audio bytes: ${audioBytes.length}');
            
            // Use just_audio to play the audio bytes directly.
            // We create a custom AudioSource that loads from the byte stream.
            final audioSource = _MyCustomAudioSource(audioBytes);
            await _audioPlayer.setAudioSource(audioSource);
            await _audioPlayer.play();
            debugPrint('Audio playback started');

          } else {
            debugPrint('Error from backend: ${response.statusCode}');
            debugPrint('Response body: ${response.body}');
            // Handle error appropriately in the UI
          }
        } catch (e) {
          debugPrint('Failed to play speech: $e');
          // Handle error
        }
      }

      void dispose() {
        _audioPlayer.dispose();
      }
    }

    // Custom AudioSource for just_audio to play audio from memory (Uint8List)
    class _MyCustomAudioSource extends StreamAudioSource {
      final Uint8List bytes;
      _MyCustomAudioSource(this.bytes);

      @override
      Future<StreamAudioResponse> request([int? start, int? end]) async {
        start ??= 0;
        end ??= bytes.length;
        return StreamAudioResponse(
          sourceLength: bytes.length,
          contentLength: end - start,
          offset: start,
          stream: Stream.value(bytes.sublist(start, end)),
          contentType: 'audio/mpeg',
        );
      }
    }
    
