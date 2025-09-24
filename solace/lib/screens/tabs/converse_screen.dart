import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui'; // Required for ImageFilter.blur
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import '../../services/elevenlabs_service.dart'; // Import the new service
import 'package:google_gemini/google_gemini.dart';

// --- List of calming, colorful particles for the background ---
const List<Color> particleColors = [
  Color(0xFFB48EAD), // Soft Lavender
  Color(0xFF88C0D0), // Calm Blue
  Color(0xFF81A1C1), // Deeper Blue
  Color(0xFFEBCB8B), // Soft Gold
  Color(0xFFA3BE8C), // Gentle Green
  Color(0xFFD08770), // Soft Terracotta
];

// --- Data class for a single particle ---
class Particle {
  late Offset position;
  late Color color;
  late double speed;
  late double theta;
  late double radius;

  Particle() {
    // Initialize with random properties
    reset();
  }

  void reset({Size bounds = Size.zero}) {
    final random = math.Random();
    // ENHANCED: Particles are even larger for a softer look
    radius = random.nextDouble() * 25 + 20;
    // ENHANCED: Slower and calmer movement
    speed = random.nextDouble() * 0.3 + 0.1;
    theta = random.nextDouble() * 2.0 * math.pi;
    color = particleColors[random.nextInt(particleColors.length)]
        .withOpacity(random.nextDouble() * 0.5 + 0.2);
    position = Offset(
      random.nextDouble() * (bounds.width == 0 ? 1 : bounds.width),
      random.nextDouble() * (bounds.height == 0 ? 1 : bounds.height),
    );
  }

  void update(Size bounds) {
    position = position + Offset(math.cos(theta) * speed, math.sin(theta) * speed);

    if (position.dx < -radius * 2 ||
        position.dx > bounds.width + radius * 2 ||
        position.dy < -radius * 2 ||
        position.dy > bounds.height + radius * 2) {
      reset(bounds: bounds);
    }
  }
}

// --- Widget to render the magical background ---
class MagicalBackground extends StatefulWidget {
  final int particleCount;
  // ENHANCED: Reduced count as particles are much larger
  const MagicalBackground({super.key, this.particleCount = 30});

  @override
  State<MagicalBackground> createState() => _MagicalBackgroundState();
}

class _MagicalBackgroundState extends State<MagicalBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25), // Slower animation loop
    )..repeat();
    
    particles = List.generate(widget.particleCount, (index) => Particle());
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final size = MediaQuery.of(context).size;
    for (var p in particles) {
      p.reset(bounds: size);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        for (var p in particles) {
          p.update(MediaQuery.of(context).size);
        }
        return CustomPaint(
          painter: _ParticlePainter(particles),
          child: Container(),
        );
      },
    );
  }
}

// --- Custom painter to draw the particles ---
class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    // ENHANCED: Paint now includes a stronger blur effect
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    for (var p in particles) {
      paint.color = p.color;
      canvas.drawCircle(p.position, p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


// --- Main Converse Screen Widget ---
class ConverseScreen extends StatefulWidget {
  const ConverseScreen({super.key});

  @override
  State<ConverseScreen> createState() => _ConverseScreenState();
}

class _ConverseScreenState extends State<ConverseScreen>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  
  // Services
  final ElevenLabsService _elevenLabsService = ElevenLabsService();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final GoogleGemini gemini = GoogleGemini(
    apiKey: "", model: "gemini-2.5-flash"
  );

  // UI Controllers
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  // State variables
  bool _isListening = false;
  bool _speechEnabled = false;

  final List<Map<String, String>> _messages = [];

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _initSpeech();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _elevenLabsService.dispose();
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  // Initialize speech-to-text
  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onStatus: (val) {
          print('Speech status: $val');
          if (val == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (val) {
          print('Speech error: $val');
          setState(() {
            _isListening = false;
          });
        },
      );
      print('Speech recognition enabled: $_speechEnabled');
    } catch (e) {
      print('Failed to initialize speech recognition: $e');
      _speechEnabled = false;
    }
    setState(() {});
  }

  // Handle speech recognition results
  void _onSpeechResult(result) {
    print('Speech result: ${result.recognizedWords}');
    print('Final result: ${result.finalResult}');

    setState(() {
      _textController.text = result.recognizedWords;
    });

    // If this is a final result and we have text, automatically send it
    if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
      print('Final speech result received, sending message');
      // Add a small delay to ensure UI updates
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isListening) {
          _toggleInteraction(); // This will stop listening and send the message
        }
      });
    }
  }

  // Send message (from text or speech)
  void _sendMessage() async {
    if (_textController.text.trim().isEmpty) return;

    final userMessage = _textController.text.trim();
    setState(() {
      _messages.insert(0, {'type': 'user', 'text': userMessage});
      _textController.clear();
    });

    // Generate Gemini response
    try {
      final value = await gemini.generateFromText(userMessage);
      _handleNewAuraMessage(value.text);
    } catch (e) {
      print('Error generating Gemini response: $e');
      _handleNewAuraMessage(
        "I'm sorry, I'm having trouble responding right now. Please try again.",
      );
    }
  }

  // // Generate AI response using backend API
  // Future<String> _generateAIResponse(String userMessage) async {
  //   try {
  //     const backendUrl = 'http://localhost:3000/api/chat/text';
  //     const userId =
  //         'flutter_user'; // You can make this dynamic based on actual user

  //     final response = await http.post(
  //       Uri.parse(backendUrl),
  //       headers: {'Content-Type': 'application/json'},
  //       body: '{"text": "$userMessage", "userId": "$userId"}',
  //     );

  //     print('AI API Response status: ${response.statusCode}');
  //     print('AI API Response body: ${response.body}');

  //     if (response.statusCode == 200) {
  //       try {
  //         // Parse the JSON response
  //         final jsonData = json.decode(response.body);
  //         return jsonData['botText'] ??
  //             "I understand. How can I help you further?";
  //       } catch (e) {
  //         print('Error parsing JSON response: $e');
  //         return "I understand. How can I help you further?";
  //       }
  //     } else {
  //       print('Error from AI backend: ${response.statusCode}');
  //       return "I understand your message. How can I assist you today?";
  //     }
  //   } catch (e) {
  //     print('Failed to get AI response: $e');
  //     return "I'm here to help. Can you tell me more about what's on your mind?";
  //   }
  // }

  // This function now simulates the full conversation loop
  void _handleNewAuraMessage(String text) {
    setState(() {
      _messages.insert(0, {'type': 'aura', 'text': text});
    });
    // NEW: When Aura "speaks", we call the service to generate and play the audio
    _elevenLabsService.playTextAsSpeech(text);
  }

  void _toggleInteraction() async {
    if (!_speechEnabled) {
      print('Speech recognition not available');
      return;
    }

    if (_isListening) {
      // Stop listening
      _orbController.stop();
      _orbController.animateTo(0, duration: const Duration(milliseconds: 300));
      await _speechToText.stop();

      setState(() {
        _isListening = false;
      });

      // If we have text from speech, send it
      if (_textController.text.trim().isNotEmpty) {
        print('Sending speech result: ${_textController.text}');
        _sendMessage();
      }
    } else {
      // Start listening
      setState(() {
        _isListening = true;
      });
      
      _orbController.repeat(reverse: true);

      await _speechToText.listen(
        onResult: _onSpeechResult,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        localeId: 'en_US',
        listenMode: stt.ListenMode.confirmation,
      );
    }
  }

  Future<void> sendGeminiMessage(String userMessage) async {
    if (userMessage.trim().isEmpty) return;
    setState(() {
      _messages.insert(0, {'type': 'user', 'text': userMessage});
      _textController.clear();
    });
    try {
      final value = await gemini.generateFromText(userMessage);
      setState(() {
        _messages.insert(0, {'type': 'bot', 'text': value.text});
      });
    } catch (e) {
      setState(() {
        _messages.insert(0, {'type': 'bot', 'text': 'Error: $e'});
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Magical background
          const MagicalBackground(),
          // Foreground content
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Solace',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: const Color(0xFF4C566A)),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isUser = message['type'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: GlassmorphicContainer(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              message['text']!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: const Color(0xFF3B4252).withOpacity(0.8)),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Text input area
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withOpacity(0.4),
                                    Colors.white.withOpacity(0.2),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: TextField(
                                controller: _textController,
                                focusNode: _textFocusNode,
                                decoration: const InputDecoration(
                                  hintText: 'Type your message...',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF3B4252),
                                ),
                                onSubmitted: (_) => _sendMessage(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.withOpacity(0.6),
                                    Colors.blue.withOpacity(0.4),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Icon(
                                Icons.send,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
                  child: GestureDetector(
                    onTap: _toggleInteraction,
                    child: AnimatedBuilder(
                      animation: _orbController,
                      builder: (context, child) {
                        final pulse = _isListening ? _orbController.value : 0.0;
                        return CustomPaint(
                          painter: GlowingOrbPainter(
                            animationValue: pulse,
                            color:
                                _isListening
                                ? Theme.of(context).colorScheme.primary
                                : const Color(0xFF4C566A),
                          ),
                          child: SizedBox(
                            width: 100,
                            height: 100,
                            child: Center(
                              child: Icon(
                                _isListening ? Icons.stop : Icons.mic,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Speech status text
                if (_speechEnabled)
                  Text(
                    _isListening
                        ? 'Listening... Tap to stop'
                        : 'Tap microphone to speak',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF4C566A).withOpacity(0.7),
                    ),
                  )
                else
                  Text(
                    'Speech recognition not available',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.red.withOpacity(0.7),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Reusable Glassmorphic Container Widget
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  const GlassmorphicContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                // ENHANCED: Gradient is more subtle to look better on a pure white background.
                colors: [
                  Colors.white.withOpacity(0.4),
                  Colors.white.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                // ENHANCED: Border is now a very light grey for subtle definition.
                color: Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Custom painter for the orb (No change)
class GlowingOrbPainter extends CustomPainter {
  final double animationValue;
  final Color color;
  GlowingOrbPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = size.width / 2;
    final glowRadius = baseRadius * (1 + animationValue * 0.3);
    final glowPaint = Paint()
      ..color = color.withOpacity(0.1 + animationValue * 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseRadius * 0.6);
    canvas.drawCircle(center, glowRadius, glowPaint);
    final mainPaint = Paint()..color = color;
    canvas.drawCircle(center, baseRadius * 0.8, mainPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}



