// import 'package:easy_first_aid/components/bottomnavbar.dart';
import 'package:easy_first_aid/screens/contentPage.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcaseview/showcaseview.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  // int _selectedIndex = 0;
  final GlobalKey globalKey1 = GlobalKey();
  final GlobalKey _homekey2 = GlobalKey();

  // bool _isFirstTime = true;

  @override
  void initState() {
    super.initState();
    _checkFirstTimeLogin(); // Check if it's the user's first time logging in
  }

  // Check if the Showcase needs to be shown
  Future<void> _checkFirstTimeLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool hasShownShowcase = prefs.getBool('hasShownShowcase') ?? false;

    if (!hasShownShowcase) {
      // Show the showcase for the first time
      WidgetsBinding.instance
          .addPostFrameCallback((_) => Future.delayed(Duration(seconds: 3), () {
                ShowCaseWidget.of(context)
                    .startShowCase([globalKey1, _homekey2]);
              }));
      // Set the flag so that it doesn't show again
      prefs.setBool('hasShownShowcase', true);
    }
  }

  // void _onItemTapped(int index) {
  //   setState(() {
  //     _selectedIndex = index;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: screenHeight * 0.26,
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 150, 197, 197),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: screenHeight * 0.05,
                ),
                Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 0, 0),
                      child: Showcase(
                        description:
                            "Let's give you a guide to use Easy First Aid",
                        key: globalKey1,
                        child: const Text(
                          "Welcome to Easy First Aid",
                          style: TextStyle(
                              fontSize: 25, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Image.asset(
                        'assets/images/FirstAid.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(15, 0, 0, 14),
                  child: Text(
                    "Always have your first aid guide in your pocket",
                    style: TextStyle(
                        fontSize: 18,
                        color: Color.fromARGB(255, 255, 255, 255)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
                  child: Text(
                    "Save lives, be a hero",
                    style: TextStyle(
                        fontSize: 18, color: Color.fromARGB(255, 61, 59, 59)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: screenHeight * 0.02),
          const Padding(
            padding: EdgeInsets.fromLTRB(15, 0, 0, 0),
            child: Text(
              "Home",
              style: TextStyle(
                  fontSize: 23,
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontWeight: FontWeight.bold),
            ),
          ),
          Row(
            children: [
              Images(
                onPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ContentPage(
                        title: "Bleeding",
                        description: "Follow the steps to cure bleeding",
                        imageUrl:
                            "https://www.shutterstock.com/image-vector/girl-fell-hurt-her-knee-600nw-1106783828.jpg",
                        step1:
                            'Gently rinse the area with clean water to remove any dirt or debris.',
                        step2:
                            'Use a clean cloth or bandage to apply gentle pressure until the bleeding stops, which usually takes a few minutes.',
                        step3:
                            'Once the bleeding stops, apply an antiseptic if available, and cover the wound with a bandage to keep it clean and prevent infection.',
                      ),
                    ),
                  );
                },
                text: "Bleeding",
                image:
                    "https://www.shutterstock.com/image-vector/girl-fell-hurt-her-knee-600nw-1106783828.jpg",
              ),
              Images(
                  onPress: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ContentPage(
                                title: "Head Injury",
                                description: "Steps to treat Head Injury",
                                imageUrl:
                                    "https://as1.ftcdn.net/v2/jpg/04/54/02/84/1000_F_454028491_XzOumVNmV1AH6VNIQ21jCogpRToQhcWR.jpg",
                                step1:
                                    "If someone has a head injury, make sure they are in a safe environment and encourage them to stay still. Avoid moving the person unless it's necessary to prevent further injury. Keep their head elevated if possible.",
                                step2:
                                    "Use a cold compress or ice wrapped in a cloth to reduce swelling. Apply it to the injured area for 15-20 minutes, but avoid placing ice directly on the skin.",
                                step3:
                                    "Watch for signs like loss of consciousness, confusion, vomiting, or severe headaches. If any of these occur, or if the injury seems severe, seek immediate medical attention. Even for mild injuries, consider medical evaluation to rule out internal damage like a concussion.")));
                  },
                  text: "Head Injury",
                  image:
                      "https://as1.ftcdn.net/v2/jpg/04/54/02/84/1000_F_454028491_XzOumVNmV1AH6VNIQ21jCogpRToQhcWR.jpg"),
              Images(
                  onPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContentPage(
                            title: "Eye Injury",
                            description: "Follow the steps to treat eye injury",
                            imageUrl:
                                "https://img.freepik.com/premium-vector/person-putting-blindfold-face_723224-1729.jpg?semt=ais_hybrid",
                            step1:
                                "If there's debris or irritation, do not rub the eye, as this can worsen the injury or cause further damage. Instead, keep the eye closed and avoid pressure.",
                            step2:
                                "If something is stuck in the eye or if chemicals are involved, gently flush the eye with clean water for at least 15 minutes. This can help remove any foreign objects or dilute harmful substances.",
                            step3:
                                "If the injury is serious—like a cut, puncture, or chemical burn—or if vision is affected, seek immediate medical attention. Do not attempt to remove embedded objects or treat serious injuries at home."),
                      ),
                    );
                  },
                  text: "Eye Injury",
                  image:
                      "https://img.freepik.com/premium-vector/person-putting-blindfold-face_723224-1729.jpg?semt=ais_hybrid"),
            ],
          ),
          Row(
            children: [
              Images(
                  onPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContentPage(
                            title: "Asthma Attack",
                            description:
                                "Follow the steps to treat Asthma attack",
                            imageUrl:
                                "https://img.freepik.com/free-vector/asthma-concept-illustration_114360-6713.jpg",
                            step1:
                                "Immediately use a rescue inhaler (usually with albuterol or another bronchodilator). Take 2-6 puffs, waiting 20-30 seconds between each puff. Follow the instructions provided by your doctor for your specific inhaler.",
                            step2:
                                "Sit in an upright position to help open your airways. Try to stay calm, as panic can worsen breathing difficulties. Focus on slow, deep breaths.",
                            step3:
                                "If the inhaler doesn’t improve symptoms after 15-20 minutes, or if breathing worsens, seek emergency medical help right away. Call for medical assistance or go to the nearest hospital."),
                      ),
                    );
                  },
                  text: "Asthma Attack",
                  image:
                      "https://img.freepik.com/free-vector/asthma-concept-illustration_114360-6713.jpg"),
              Images(
                  onPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContentPage(
                            title: "Bone Fracture",
                            description:
                                "Follow the steps to treat bone fracture",
                            imageUrl:
                                "https://static.vecteezy.com/system/resources/previews/006/631/059/original/little-boy-with-broken-arm-concept-of-treatment-bone-fracture-plaster-cast-on-broken-arm-children-s-medicine-cartoon-illustration-in-flat-style-vector.jpg",
                            step1:
                                "Keep the injured area still and avoid moving it to prevent further damage. Use a splint, or if unavailable, a makeshift splint like a board or rolled-up towel to support the limb.",
                            step2:
                                " Place an ice pack wrapped in a cloth on the injured area to reduce swelling and pain. Avoid placing ice directly on the skin and limit icing to 15-20 minutes at a time.",
                            step3:
                                "Get professional medical attention as soon as possible. Do not try to realign the bone or push any bone back in if it’s visible. Keep the person calm and still until help arrives."),
                      ),
                    );
                  },
                  text: "Bone Fracture",
                  image:
                      "https://static.vecteezy.com/system/resources/previews/006/631/059/original/little-boy-with-broken-arm-concept-of-treatment-bone-fracture-plaster-cast-on-broken-arm-children-s-medicine-cartoon-illustration-in-flat-style-vector.jpg"),
              Images(
                  onPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContentPage(
                            title: "Heart Attack",
                            description:
                                "Follow the steps to cure heart attack",
                            imageUrl:
                                "https://media.istockphoto.com/id/1402909856/vector/old-man-holding-his-chest-with-heart-attack-symbol-elderly-peoples-risk.jpg?s=612x612&w=0&k=20&c=RbM1rICS_ZfpAeIqwvH-pYRr9GZDyfqNvg29CNz-t3M=",
                            step1:
                                "Dial emergency services immediately. Time is crucial in treating a heart attack, so seek professional medical help as soon as possible.",
                            step2:
                                "If the person is conscious and not allergic to aspirin, have them chew and swallow an aspirin (usually 325 mg). Aspirin can help prevent further blood clotting. Do not give aspirin if the person is allergic or has been advised against it by a healthcare provider.",
                            step3:
                                "Have the person sit down and stay calm. If they are conscious, keep them in a comfortable position, ideally with their head elevated. Avoid any physical exertion until help arrives."),
                      ),
                    );
                  },
                  text: "Heart Attack",
                  image:
                      "https://media.istockphoto.com/id/1402909856/vector/old-man-holding-his-chest-with-heart-attack-symbol-elderly-peoples-risk.jpg?s=612x612&w=0&k=20&c=RbM1rICS_ZfpAeIqwvH-pYRr9GZDyfqNvg29CNz-t3M="),
            ],
          ),
          Row(
            children: [
              Images(
                  onPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContentPage(
                            title: "Stings/bites",
                            description:
                                "Follow the steps to treat stings/bites",
                            imageUrl:
                                "https://media.istockphoto.com/id/1291648444/vector/man-suffering-from-bee-allergy.jpg?s=612x612&w=0&k=20&c=7LldAoItqad5x39bkV_ktHQbXximQvkK64Lr2ae4VG0=",
                            step1:
                                "Wash the affected area with soap and water to reduce the risk of infection. This helps remove any venom or bacteria from the bite or sting site.",
                            step2:
                                "Use a cold pack or a cloth-wrapped ice pack on the affected area for 10-15 minutes to reduce swelling and pain. Avoid placing ice directly on the skin.",
                            step3:
                                "Over-the-counter antihistamines or anti-itch creams can help relieve itching and swelling. Monitor for severe allergic reactions (such as difficulty breathing, swelling of the face or throat, or hives). If these symptoms occur, seek emergency medical help immediately. If the sting or bite is from a venomous creature or if symptoms worsen, consult a healthcare professional."),
                      ),
                    );
                  },
                  text: "Stings/bites",
                  image:
                      "https://media.istockphoto.com/id/1291648444/vector/man-suffering-from-bee-allergy.jpg?s=612x612&w=0&k=20&c=7LldAoItqad5x39bkV_ktHQbXximQvkK64Lr2ae4VG0="),
              Images(
                  onPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContentPage(
                            title: "Hypothermia",
                            description:
                                "Follow the steps to treat Hypothermia ",
                            imageUrl:
                                "https://media.istockphoto.com/id/1441535653/vector/woman-shivering-from-cold-weather-in-flat-design-on-white-background.jpg?s=612x612&w=0&k=20&c=H_yKvo8BC0lRKmtkWzd8LNb3oGEy6axya1ucq-Hqs5w=",
                            step1:
                                "Get the person to a warm, dry place as quickly as possible. If this isn’t immediately possible, create a shelter to protect them from wind and rain.",
                            step2:
                                "Remove any wet clothing and replace it with dry, warm layers. Use blankets, towels, or other warm clothing to gently warm them. Avoid using direct heat sources like hot water or heating pads, as rapid warming can cause burns or other complications.",
                            step3:
                                "Offer warm, non-alcoholic, non-caffeinated beverages if the person is conscious and able to drink. This helps raise their core temperature. Avoid giving anything to eat or drink if they are confused or unconscious."),
                      ),
                    );
                  },
                  text: "Hypothermia",
                  image:
                      "https://media.istockphoto.com/id/1441535653/vector/woman-shivering-from-cold-weather-in-flat-design-on-white-background.jpg?s=612x612&w=0&k=20&c=H_yKvo8BC0lRKmtkWzd8LNb3oGEy6axya1ucq-Hqs5w="),
              Images(
                  onPress: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ContentPage(
                            title: "Skin burns",
                            description:
                                "Follow the steps to treat skin burns ",
                            imageUrl:
                                "https://cdni.iconscout.com/illustration/premium/thumb/woman-with-sunburn-damage-5200039-4341061.png?f=webp",
                            step1:
                                "Immediately cool the burn by running it under cool (not cold) water for 10-15 minutes. This helps reduce pain and prevent further skin damage. If running water isn't available, apply a cool, wet cloth to the area.",
                            step2:
                                "Gently cover the burn with a sterile, non-stick bandage or clean cloth. Avoid using ice, butter, or any ointments on the burn, as these can cause further irritation.",
                            step3:
                                "For severe burns (blisters, large areas of skin affected, or burns on the face, hands, feet, or genitals), seek professional medical attention immediately. For minor burns, monitor for signs of infection and consult a healthcare provider if needed."),
                      ),
                    );
                  },
                  text: "Skin burns",
                  image:
                      "https://cdni.iconscout.com/illustration/premium/thumb/woman-with-sunburn-damage-5200039-4341061.png?f=webp"),
            ],
          ),
        ],
      ),
      // bottomNavigationBar: Showcase(
      //   description: "Navigate between different screens from here",
      //   key: _homekey2,
      //   child: BottomNavBar(
      //     currentIndex: _selectedIndex,
      //     onTap: _onItemTapped,
      //   ),
      // ),
    );
  }
}

class Images extends StatefulWidget {
  final String text, image;
  final VoidCallback? onPress;
  final bool addShadow; // Property to control shadow

  const Images({
    super.key,
    required this.text,
    required this.image,
    this.onPress,
    this.addShadow = false, // Default value is false (no shadow)
  });

  @override
  State<Images> createState() => _ImagesState();
}

class _ImagesState extends State<Images> {
  final GlobalKey _globalKey2 = GlobalKey();

  @override
  void initState() {
    super.initState();
    _checkFirstTimeUser();
  }

  // Method to check if this is the user's first time on the screen
  Future<void> _checkFirstTimeUser() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstTime = prefs.getBool('isFirstTimeShowcase') ?? true;

    if (isFirstTime) {
      // If it's the first time, start the showcase and set the flag to false
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(seconds: 9), () {
          ShowCaseWidget.of(context).startShowCase([_globalKey2]);
        });
      });
      await prefs.setBool('isFirstTimeShowcase', false); // Update the flag
    }
  }

  @override
  Widget build(BuildContext context) {
    return Flexible(
      flex: 1,
      child: Padding(
        padding: const EdgeInsets.only(
            left: 8.0,
            right: 8.0,
            bottom: 8.0), // Padding added on all sides except top
        child: InkWell(
          onTap: widget.onPress,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12), // Add border radius
                  boxShadow: widget.addShadow
                      ? [
                          BoxShadow(
                            color:
                                Colors.black.withOpacity(0.7), // Darker shadow
                            spreadRadius: 6, // Increased spread radius
                            blurRadius: 10, // Increased blur radius
                            offset: const Offset(0, 4), // Increased offset
                          ),
                        ]
                      : [], // No shadow if addShadow is false
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                        12), // Clip image with border radius
                    child: Showcase(
                      key: _globalKey2,
                      description: "Press the image to know the treatment",
                      child: Image.network(
                        widget.image,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8), // Space between image and text
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.text,
                    style: const TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
