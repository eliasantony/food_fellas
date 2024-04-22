import 'dart:developer';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final _openAI = OpenAI.instance.build(
      token: dotenv.env['OPENAI_API_KEY']!,
      baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 10)),
      enableLog: true);

  final ChatUser _currentUser =
      ChatUser(id: '1', firstName: 'Elias', lastName: 'Antony');
  final ChatUser _gptChatUser =
      ChatUser(id: '2', firstName: 'Chat', lastName: 'GPT');

  List<ChatMessage> _messages = <ChatMessage>[];
  List<ChatUser> _typingUsers = <ChatUser>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('AI Chat'),
        ),
        body: DashChat(
          currentUser: _currentUser,
          typingUsers: _typingUsers,
          messageOptions: const MessageOptions(
            currentUserContainerColor: Colors.black,
            containerColor: Color.fromRGBO(0, 166, 126, 1),
            textColor: Colors.white,
          ),
          onSend: (ChatMessage message) {
            getChatResponse(message);
          },
          messages: _messages,
        ));
  }

  Future<void> getChatResponse(ChatMessage message) async {
    setState(() {
      _messages.insert(0, message);
      _typingUsers.add(_gptChatUser);
    });

    List<Messages> _messagesHistory = _messages.reversed.map((m) {
      if (m.user == _currentUser) {
        return Messages(
          role: Role.user,
          content: m.text,
        );
      } else {
        return Messages(
          role: Role.assistant,
          content: m.text,
        );
      }
    }).toList();

    final request = ChatCompleteText(
        model: GptTurbo0301ChatModel(),
        messages: _messagesHistory,
        maxToken: 500);

    final response = await _openAI.onChatCompletion(request: request);

    for (var element in response!.choices) {
      if (element.message != null) {
        setState(() {
          _messages.insert(
              0,
              ChatMessage(
                text: element.message!.content,
                user: _gptChatUser,
                createdAt: DateTime.now(),
              ));
        });
      }
    }
    setState(() {
      _typingUsers.remove(_gptChatUser);
    });
  }
}
