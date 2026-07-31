import 'package:flutter/material.dart';

class ChatBotHome extends StatefulWidget {
  const ChatBotHome({super.key});

  @override
  State<ChatBotHome> createState() => _ChatBotHomeState();
}

class _ChatBotHomeState extends State<ChatBotHome> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text: 'Hello! Welcome to Tremsol. How may we assist you today?',
      isUserMessage: false,
    ),
  ];

  bool _isResponding = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final String text = _controller.text.trim();

    if (text.isEmpty || _isResponding) {
      return;
    }

    _controller.clear();

    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUserMessage: true,
        ),
      );

      _isResponding = true;
    });

    _scrollToBottom();

    try {
      // Temporary delay to simulate a response.
      await Future<void>.delayed(
        const Duration(milliseconds: 600),
      );

      if (!mounted) {
        return;
      }

      final String response = _generateLocalResponse(text);

      setState(() {
        _messages.add(
          _ChatMessage(
            text: response,
            isUserMessage: false,
          ),
        );

        _isResponding = false;
      });

      _scrollToBottom();
    } catch (error) {
      debugPrint('Chat response error: $error');

      if (!mounted) {
        return;
      }

      setState(() {
        _messages.add(
          const _ChatMessage(
            text:
                'Sorry, something went wrong. Please try sending your message again.',
            isUserMessage: false,
          ),
        );

        _isResponding = false;
      });

      _scrollToBottom();
    }
  }

  String _generateLocalResponse(String message) {
    final String input = message.toLowerCase();

    if (_containsAny(input, [
      'hello',
      'hi',
      'hey',
      'good morning',
      'good afternoon',
      'good evening',
    ])) {
      return 'Hello! How may Tremsol assist you today?';
    }

    if (_containsAny(input, [
      'job',
      'jobs',
      'employment',
      'vacancy',
      'vacancies',
      'career',
    ])) {
      return 'You can browse available opportunities from the Jobs section of the Tremsol app.';
    }

    if (_containsAny(input, [
      'movie',
      'movies',
      'film',
      'films',
    ])) {
      return 'You can explore available content from the Movies section.';
    }

    if (_containsAny(input, [
      'game',
      'games',
      'gaming',
    ])) {
      return 'You can explore games from the Games section of the app.';
    }

    if (_containsAny(input, [
      'fashion',
      'clothes',
      'clothing',
      'style',
    ])) {
      return 'You can browse fashion content and products from the Fashion section.';
    }

    if (_containsAny(input, [
      'shop',
      'product',
      'products',
      'buy',
      'seller',
    ])) {
      return 'You can browse available products in the Shop section and contact the seller for further information.';
    }

    if (_containsAny(input, [
      'payment',
      'pay',
      'paystack',
      'transaction',
    ])) {
      return 'Please select one of the payment options provided in the app. Make sure your network connection is stable before completing the transaction.';
    }

    if (_containsAny(input, [
      'login',
      'sign in',
      'password',
      'account',
    ])) {
      return 'Please confirm that your email address and password are correct. You can also use the password recovery option when necessary.';
    }

    if (_containsAny(input, [
      'register',
      'registration',
      'sign up',
      'create account',
    ])) {
      return 'You can create a Tremsol account from the Sign Up screen using your valid details.';
    }

    if (_containsAny(input, [
      'thank',
      'thanks',
    ])) {
      return 'You are welcome. We are happy to assist you!';
    }

    if (_containsAny(input, [
      'bye',
      'goodbye',
      'see you',
    ])) {
      return 'Goodbye! Thank you for using Tremsol.';
    }

    return 'Thank you for contacting Tremsol. Please provide a little more information about the assistance you need.';
  }

  bool _containsAny(String input, List<String> keywords) {
    return keywords.any(input.contains);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chat with Us',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF002A5C),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(16),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _MessagesScreen(
                messages: _messages,
                scrollController: _scrollController,
              ),
            ),
            if (_isResponding)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFFF6F00),
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Tremsol is responding...',
                      style: TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            _buildMessageComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF002A5C),
              ),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: const TextStyle(
                  color: Colors.grey,
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFF002A5C),
                    width: 1.2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: const Color(0xFFFF6F00),
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(
              tooltip: 'Send message',
              onPressed: _isResponding ? null : _sendMessage,
              icon: const Icon(
                Icons.send_rounded,
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUserMessage,
  });

  final String text;
  final bool isUserMessage;
}

class _MessagesScreen extends StatelessWidget {
  const _MessagesScreen({
    required this.messages,
    required this.scrollController,
  });

  final List<_ChatMessage> messages;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ),
        itemCount: messages.length,
        itemBuilder: (BuildContext context, int index) {
          final _ChatMessage message = messages[index];

          return _MessageBubble(
            message: message,
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
  });

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final bool isUser = message.isUserMessage;

    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF002A5C)
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : const Color(0xFF002A5C),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}