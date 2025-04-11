import 'package:easy_first_aid/screens/Inventory_Screens/taskscreen.dart';
import 'package:easy_first_aid/screens/Maps/mapscreen.dart';
import 'package:easy_first_aid/screens/ai_assistant.dart';
import 'package:easy_first_aid/screens/emergencynumbers.dart';
import 'package:easy_first_aid/screens/homescreen.dart';
import 'package:easy_first_aid/screens/symptomscheck.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'detectImage.dart';

class HomeScreen extends StatelessWidget {
  final List<Map<String, dynamic>> services =
  [
    {
      'name': 'Injury Guide',
      // 'icon': 'assets/first_aid.svg',
      'color': LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.red.shade500, Colors.pink.shade500],
      ),
      'screen': const Homescreen(),
    },
    {
      'name': 'Emergency Numbers',
      // 'icon': 'assets/emergency_call.svg',
      'color': LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.blue.shade500, Colors.purple.shade500],
      ),
      'screen': Emergencynumbers(previousIndex: null),
    },
    {
      'name': 'Easy AI',
      // 'icon': 'assets/chatbot.svg',
      'color': LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.green.shade500, Colors.teal.shade500],
      ),
      'screen': const GeminiApp(),
    },
    {
      'name': 'Symptoms',
      // 'icon': 'assets/symptom_checker.svg',
      'color': LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.yellow.shade500, Colors.orange.shade500],
      ),
      'screen': const Symptomscheck(),
    },
    {
      'name': 'Personal FirstAid box',
      // 'icon': 'assets/firstaid_kit.svg',
      'color': LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.indigo.shade500, Colors.blue.shade500],
      ),
      'screen': const Taskscreen(),
    },
    {
      'name': 'Analyze Image',
      // 'icon': 'assets/detectimage.svg',
      'color': LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.purple.shade500, Colors.blue.shade500],
      ),
      'screen':  SkinConditionAnalyzer(),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 20, 10, 10),
              child: SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.purple.shade600, Colors.pink.shade600],
                    ),
                  ),
                  child: const Text(
                    'Easy-First-Aid',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // Main content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Services grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1,
                      ),
                      itemCount: services.length,
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      services[index]['screen']),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: services[index]['color'],
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // SvgPicture.asset(
                                //   services[index]['icon'],
                                //   height: 40,
                                //   width: 40,
                                //   color: Colors.white,
                                // ),
                                const SizedBox(height: 8),
                                Text(
                                  services[index]['name'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    // Map feature
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const Mapscreen()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade600,
                              Colors.cyan.shade600
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Find Hospitals',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Locate nearby medical facilities',
                                  style: TextStyle(color: Colors.blue[100]),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: SvgPicture.asset(
                                'assets/map.svg',
                                height: 24,
                                width: 24,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
