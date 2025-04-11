// import 'package:easy_first_aid/components/bottomnavbar.dart';
import 'package:flutter/material.dart';
import 'dart:convert'; // For jsonDecode
import 'package:flutter/services.dart'; // For loading asset files

class Symptomscheck extends StatefulWidget {
  const Symptomscheck({super.key});

  @override
  State<Symptomscheck> createState() => _SymptomscheckState();
}

class _SymptomscheckState extends State<Symptomscheck> {
  // int _selectedIndex = 3;
  // Controller for the search text field
  final TextEditingController searchController = TextEditingController();

  // List of symptoms to be displayed
  List<String> symptoms = [];

  // List of symptoms selected by the user
  List<String> selectedSymptoms = [];

  // List of symptoms filtered based on user input in the search field
  List<String> filteredSymptoms = [];

  // Map that contains diseases as keys and their associated symptoms as values
  Map<String, List<String>> diseaseSymptoms = {};

  // List of all available symptoms (populated from the JSON dataset)
  List<String> availableSymptoms = [];

  // Stores the current search query entered by the user
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSymptomsData(); // Load the symptoms data when the widget is first created
  }

  // Method to load symptoms data from the JSON file in assets
  Future<void> _loadSymptomsData() async {
    final data =
        await rootBundle.loadString('assets/dataset.json'); // Load JSON file
    final List<dynamic> jsonData = jsonDecode(data); // Parse JSON

    // Set to store all unique symptoms
    Set<String> allSymptoms = {};

    // Map to store diseases and their related symptoms
    Map<String, List<String>> diseaseSymptomsMap = {};

    for (var disease in jsonData) {
      final Map<String, dynamic> diseaseMap = disease as Map<String, dynamic>;
      String diseaseName = diseaseMap['Disease'] as String;
      List<String> symptomsList = [];

      // Iterate through each key in the diseaseMap and find symptoms
      for (var key in diseaseMap.keys) {
        if (key.startsWith('Symptom_') &&
            diseaseMap[key].toString().trim().isNotEmpty) {
          // Add the symptom to the list and also to the set of all symptoms
          symptomsList.add(diseaseMap[key].toString().trim());
          allSymptoms.add(diseaseMap[key].toString().trim());
        }
      }

      if (symptomsList.isNotEmpty) {
        // Add the disease and its symptoms to the map
        diseaseSymptomsMap[diseaseName] = symptomsList;
      }
    }

    setState(() {
      availableSymptoms =
          allSymptoms.toList(); // Convert set to list for display
      filteredSymptoms =
          availableSymptoms; // Initialize filtered list with all symptoms
      diseaseSymptoms =
          diseaseSymptomsMap; // Store the map of diseases and symptoms
    });
  }

  // Method to filter symptoms based on the user's search query
  void _filterSymptoms(String query) {
    setState(() {
      searchQuery = query; // Store the current search query
      final lowerCaseQuery = query
          .toLowerCase(); // Convert to lowercase for case-insensitive search
      filteredSymptoms = availableSymptoms.where((symptom) {
        return symptom
            .toLowerCase()
            .contains(lowerCaseQuery); // Return only matching symptoms
      }).toList();
    });
  }

  // Method to add a selected symptom to the list of selected symptoms
  void _addSymptom(String symptom) {
    if (!selectedSymptoms.contains(symptom)) {
      // Avoid duplicate entries
      setState(() {
        selectedSymptoms.add(symptom); // Add the symptom to the list
        searchController.clear(); // Clear the text field after adding
        filteredSymptoms =
            availableSymptoms; // Reset the filtered symptoms to all available symptoms
      });
    }
  }

  // Method to remove a selected symptom from the list
  void _removeSymptom(int index) {
    setState(() {
      selectedSymptoms.removeAt(index); // Remove the symptom at the given index
    });
  }

  // Method to search for diseases based on selected symptoms
  void _searchDiseases() {
    final results = diseaseSymptoms.entries
        .where((entry) => entry.value
            .toSet()
            .intersection(selectedSymptoms
                .toSet()) // Check for matching symptoms between disease and selected symptoms
            .isNotEmpty)
        .map((entry) => entry.key) // Extract matching diseases
        .toList();

    // Show the matching diseases in a dialog
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Matching Diseases'),
          content: Text(results.isNotEmpty
              ? results.join(', ') // Show the diseases if there are matches
              : 'No matching diseases found.'), // Show a message if no matches are found
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close the dialog
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // on Item Tap function of bottomnavbar
  // void onItemTapped(int index) {
  //   setState(() {
  //     _selectedIndex = index;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white, // Set background color of the screen
      body: Column(
        children: [
          // Upper section with title and input field
          Container(
            height: screenHeight * 0.4,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 150, 197, 197),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40), // Rounded corners
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: screenHeight * 0.01),
                Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
                      child: Text(
                        "Symptoms Checker",
                        style: TextStyle(
                          fontSize: 25, // Title size
                          fontWeight: FontWeight.bold, // Bold text
                          color: Color.fromARGB(255, 176, 36, 26), // Text color
                        ),
                      ),
                    ),
                    Expanded(
                      child: Image.asset(
                        'assets/images/FirstAid.png',
                        fit: BoxFit
                            .contain, // Ensure the image fits within the available space
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.02),
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: TextFormField(
                          controller:
                              searchController, // Attach search controller to input field
                          cursorColor: const Color.fromARGB(
                              255, 226, 0, 0), // Cursor color
                          decoration: InputDecoration(
                            filled:
                                true, // Background color for the input field
                            fillColor: const Color.fromARGB(
                                255, 255, 255, 255), // White background
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(
                                  Radius.circular(20)), // Rounded corners
                              borderSide: BorderSide.none, // No border
                            ),
                            hintText: "Search for symptoms", // Placeholder text
                            suffixIcon: IconButton(
                              onPressed: () => _addSymptom(searchController.text
                                  .trim()), // Add symptom when icon is pressed
                              icon: const Icon(Icons.add),
                              color: const Color.fromARGB(255, 152, 14, 14),
                            ),
                          ),
                          onChanged:
                              _filterSymptoms, // Filter symptoms when the user types
                        ),
                      ),
                    ),
                    SizedBox(width: screenWidth * 0.01),
                    // Search button
                    InkWell(
                      onTap: _searchDiseases, // Trigger search when tapped
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: screenWidth * 0.1,
                        height: screenHeight * 0.08,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color:
                              Colors.grey[800], // Dark color for search button
                          shape: BoxShape.circle, // Circular button
                        ),
                        child: const Icon(
                          Icons.search,
                          color: Colors.white, // White search icon
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: screenHeight * 0.01),
                // List of selected symptoms
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: SingleChildScrollView(
                    scrollDirection:
                        Axis.horizontal, // Allow horizontal scrolling
                    child: Wrap(
                      spacing: 8.0, // Space between symptoms
                      runSpacing: 8.0, // Space between rows
                      children: List.generate(selectedSymptoms.length, (index) {
                        return Container(
                          padding: const EdgeInsets.all(8.0),
                          decoration: BoxDecoration(
                            color: Colors
                                .white, // White background for selected symptoms
                            borderRadius:
                                BorderRadius.circular(10), // Rounded corners
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 5,
                                offset: Offset(0, 3), // Shadow below the box
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize:
                                MainAxisSize.min, // Take minimal space
                            children: [
                              Text(
                                selectedSymptoms[index],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.black, // Text color
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.02),
                              IconButton(
                                icon: const Icon(Icons
                                    .close), // Close icon for removing symptoms
                                color:
                                    Colors.red, // Red color for remove button
                                onPressed: () => _removeSymptom(
                                    index), // Remove symptom when pressed
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          // Lower section with symptom search results
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search from the below Symptoms',
                    style: TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontSize: 20, // Heading for symptom list
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  // Display the list of filtered symptoms
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredSymptoms
                          .length, // Total number of filtered symptoms
                      itemBuilder: (context, index) {
                        final symptom = filteredSymptoms[index];

                        return GestureDetector(
                          onTap: () {
                            _addSymptom(
                                symptom); // Add the selected symptom when tapped
                            FocusScope.of(context)
                                .unfocus(); // Hide the keyboard
                          },
                          child: AnimatedContainer(
                            duration: Duration(
                                milliseconds: 300), // Animation duration
                            curve: Curves.easeInOut, // Animation curve
                            margin: const EdgeInsets.symmetric(
                                vertical: 5.0,
                                horizontal: 10.0), // Margin around each symptom
                            padding: const EdgeInsets.all(
                                12.0), // Padding inside each container
                            decoration: BoxDecoration(
                              color: Color.fromARGB(255, 150, 197, 197)
                                  .withOpacity(0.6), // Background color
                              borderRadius: BorderRadius.circular(
                                  10.0), // Rounded corners
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withOpacity(0.2), // Shadow color
                                  spreadRadius: 4,
                                  blurRadius: 5,
                                  offset: Offset(0, 3), // Position of shadow
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    symptom,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      color: Color.fromARGB(255, 0, 0,
                                          0), // White text for each symptom
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // / Add icon to indicate adding the symptom
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      // bottomNavigationBar:
      //     BottomNavBar(currentIndex: _selectedIndex, onTap: onItemTapped),
    );
  }
}
