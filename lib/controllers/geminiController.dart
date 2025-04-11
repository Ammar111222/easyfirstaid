import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:get/get.dart';
import 'package:dash_chat_2/dash_chat_2.dart';

class GeminiChatController extends GetxController {
  final Gemini gemini = Gemini.instance;
  final RxList<ChatMessage> messages = <ChatMessage>[].obs;

  final ChatUser currentUser = ChatUser(
    id: '0',
    firstName: 'noman',
    lastName: 'butt',
  );

  final ChatUser geminiUser = ChatUser(
    id: '1',
    firstName: 'Easy',
    lastName: 'AI',
  );

  // List of health-related keywords for filtering valid questions
  final List<String> healthKeywords = [
    // General Health
    "health", "wellness", "fitness", "nutrition", "diet", "hygiene", "exercise",
    "mental health", "stress", "hydration", "vitamins", "immunity",

    // First Aid
    "first aid", "CPR", "resuscitation", "breathing", "emergency", "wound care",
    "triage", "survival", "life support",

    // Injuries and Wounds
    "injury", "wound", "bleeding", "fracture", "sprain", "strain", "bruise",
    "burn", "cut", "laceration", "puncture", "broken bone", "dislocation",
    "abrasion", "pain", "hurt",

    // Medical Conditions
    "asthma", "allergy", "anaphylaxis", "diabetes", "hypertension", "stroke",
    "heart attack", "seizure", "shock", "unconscious", "fainting", "choking",
    "concussion", "hypothermia", "heatstroke", "dehydration", "hyperthermia",
    "poisoning", "overdose", "infection",

    // Specific Body Parts
    "head injury", "eye injury", "back injury", "chest pain", "abdominal pain",
    "leg injury", "arm injury", "foot injury", "hand injury",

    // Treatment Methods
    "bandage", "splint", "tourniquet", "ice pack", "defibrillator",
    "pain relief", "antiseptic", "dressing", "compress", "stitches", "ointment",
    "splinting", "immobilization", "gauze", "disinfectant",

    // Common Illnesses
    "fever", "cold", "flu", "cough", "headache", "stomach ache", "dizziness",
    "nausea", "vomiting", "diarrhea", "ear infection", "sore throat",

    // Respiratory Issues
    "shortness of breath", "asthma attack", "breathing difficulties",
    "hyperventilation", "airway obstruction", "respiratory distress",

    // Cardiac Emergencies
    "cardiac arrest", "heart failure", "arrhythmia", "palpitations",
    "chest compression", "defibrillation", "angina", "coronary artery disease",

    // Other Emergencies
    "drowning", "electric shock", "chemical burn", "toxic exposure", "bite",
    "sting", "snakebite", "spider bite", "allergic reaction", "food poisoning"
  ];

  /// Checks if a question contains health-related keywords
  bool isHealthRelated(String question) {
    final lowerCaseQuestion = question.toLowerCase();
    return healthKeywords.any(
          (keyword) => lowerCaseQuestion.contains(keyword.toLowerCase()),
    );
  }

  /// Handles user message sending and AI response generation
  void sendMessage(ChatMessage chatMessage) {
    // Add user message to chat
    messages.insert(0, chatMessage);
    final String question = chatMessage.text;

    // Validate if question is health-related
    if (isHealthRelated(question)) {
      // Generate AI response for health-related questions
      _generateAIResponse(question);
    } else {
      // Send warning for non-health-related questions
      addGeminiMessage(
        "Please ask only health or first-aid-related questions. Thanks!",
      );
    }
  }

  /// Generates AI response using Gemini API
  void _generateAIResponse(String question) {
    gemini.streamGenerateContent(question).listen((event) {
      // Fixed: Access the content safely without using .text which is undefined
      String response = "";
      if (event.content != null && event.content!.parts != null) {
        // Process each part correctly based on the actual API
        for (var part in event.content!.parts!) {
          // Check the type of part and extract text accordingly
          if (part is TextPart) {
            response += " ${part.text}";
          } else {
            // Handle other part types if needed
          }
        }
      }

      response = response.trim();
      if (response.isNotEmpty) {
        addGeminiMessage(response);
      }
    });
  }

  /// Adds an AI message to the chat history
  void addGeminiMessage(String response) {
    final ChatMessage message = ChatMessage(
      user: geminiUser,
      createdAt: DateTime.now(),
      text: response,
    );

    messages.insert(0, message);
  }
}