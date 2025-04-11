import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_ml_model_downloader/firebase_ml_model_downloader.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class SkinConditionAnalyzer extends StatefulWidget {
  const SkinConditionAnalyzer({Key? key}) : super(key: key);

  @override
  _SkinConditionAnalyzerState createState() => _SkinConditionAnalyzerState();
}

class _SkinConditionAnalyzerState extends State<SkinConditionAnalyzer> {
  // Model constants
  static const String _modelName = 'FAmodel';
  static const List<String> _conditionLabels = ['Acne', 'Bruises', 'Burns', 'Cut'];
  static const double _confidenceThreshold = 0.88;
  static const int _imageSize = 224;

  // State variables
  File? _imageFile;
  String? _predictedLabel;
  String? _cureSteps;
  Interpreter? _interpreter;

  bool _isModelLoading = true;
  bool _isProcessing = false;
  bool _isResultDisplayed = false;
  bool _isCureStepsLoading = false;
  bool _isCureStepsDisplayed = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _showImagePickerDialog();
  }

  Future<void> _loadModel() async {
    try {
      final conditions = FirebaseModelDownloadConditions();
      final customModel = await FirebaseModelDownloader.instance
          .getModel(_modelName, FirebaseModelDownloadType.localModel, conditions);

      _interpreter = await Interpreter.fromFile(customModel.file);

      setState(() {
        _isModelLoading = false;
      });
    } catch (error) {
      debugPrint('Error loading model: $error');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load model: $error'))
        );
      }
    }
  }

  Future<void> _showImagePickerDialog() async {
    await Future.delayed(Duration.zero);
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => AlertDialog(
        title: const Text('Select Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera),
              title: const Text('Camera'),
              onTap: () => _handleImageSelection(ImageSource.camera, context),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () => _handleImageSelection(ImageSource.gallery, context),
            ),
          ],
        ),
      ),
    );
  }

  void _handleImageSelection(ImageSource source, BuildContext dialogContext) {
    Navigator.of(dialogContext).pop();
    _getImage(source);
  }

  Future<void> _getImage(ImageSource source) async {
    if (_isModelLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please wait for the model to load'))
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _isProcessing = true;
        _isResultDisplayed = false;
        _isCureStepsDisplayed = false;
      });

      try {
        // Process image
        final imageBytes = await _imageFile!.readAsBytes();
        final preprocessedImage = await _preprocessImage(imageBytes);

        // Simulate processing time (optional)
        await Future.delayed(const Duration(seconds: 1));

        // Predict image
        await _predictImage(preprocessedImage);

        // Show result
        setState(() {
          _isProcessing = false;
          _isResultDisplayed = true;
        });

        // Show cure steps with delay
        setState(() {
          _isCureStepsLoading = true;
        });

        await Future.delayed(const Duration(seconds: 1));

        setState(() {
          _isCureStepsLoading = false;
          _isCureStepsDisplayed = true;
        });
      } catch (error) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing image: $error'))
        );
      }
    }
  }

  Future<List<List<List<List<double>>>>> _preprocessImage(Uint8List imageBytes) async {
    // Decode and resize image
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw Exception("Failed to decode image");
    }

    final resizedImage = img.copyResize(
        image,
        width: _imageSize,
        height: _imageSize
    );

    // Convert to normalized float tensor [1, 224, 224, 3]
    return List.generate(
      1,
          (_) => List.generate(
        _imageSize,
            (y) => List.generate(
          _imageSize,
              (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0
            ];
          },
        ),
      ),
    );
  }

  Future<void> _predictImage(List<List<List<List<double>>>> input) async {
    if (_interpreter == null) {
      throw Exception("Model not loaded");
    }

    // Run inference
    final outputTensor = List.filled(1, List.filled(_conditionLabels.length, 0.0));
    _interpreter!.run(input, outputTensor);

    // Get prediction
    final probabilities = List<double>.from(outputTensor[0]);
    final maxProbability = probabilities.reduce((a, b) => a > b ? a : b);
    final classIdx = probabilities.indexOf(maxProbability);

    // Check confidence threshold
    if (maxProbability >= _confidenceThreshold) {
      setState(() {
        _predictedLabel = _conditionLabels[classIdx];
        _cureSteps = _getCureSteps(_conditionLabels[classIdx]);
      });
    } else {
      setState(() {
        _predictedLabel = 'Uncertain Prediction';
        _cureSteps = 'Consider consulting a healthcare professional for proper diagnosis.';
      });
    }
  }

  String _getCureSteps(String label) {
    switch (label) {
      case 'Acne':
        return "- Cleanse your face with a gentle cleanser twice a day.\n"
            "- Use a salicylic acid or benzoyl peroxide-based treatment.\n"
            "- Avoid touching or picking at pimples.\n"
            "- Moisturize with non-comedogenic products.\n"
            "- Consult a dermatologist if acne persists.";
      case 'Bruises':
        return "- Apply an ice pack for 15-20 minutes every hour in the first day.\n"
            "- Elevate the affected area to reduce swelling.\n"
            "- Avoid putting pressure on the bruise.\n"
            "- Use over-the-counter pain relievers if necessary.\n"
            "- Monitor for signs of severe injury or infection.";
      case 'Burns':
        return "- Rinse the burn with cool (not cold) water for 10-15 minutes.\n"
            "- Avoid applying ice or butter to the burn.\n"
            "- Cover with a clean, non-stick sterile bandage.\n"
            "- Take pain relievers if needed for discomfort.\n"
            "- Seek medical attention if the burn is deep or covers a large area.";
      case 'Cut':
        return "- Rinse the cut with clean water to remove debris.\n"
            "- Stop bleeding by applying gentle pressure with a clean cloth.\n"
            "- Apply an antibiotic ointment to prevent infection.\n"
            "- Cover with a sterile adhesive bandage or gauze.\n"
            "- Change the dressing daily and monitor for signs of infection.";
      default:
        return "No specific cure steps available. Please consult a healthcare provider.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1d2630),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1d2630),
        foregroundColor: Colors.white,
        title: const Text("Skin Condition Analyzer"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_camera),
            onPressed: () => _showImagePickerDialog(),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isModelLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Loading analysis model...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildImageSection(),
            const SizedBox(height: 20),
            _buildResultsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    if (_imageFile == null) {
      return Container(
        height: 250,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.image, size: 80, color: Colors.white54),
            SizedBox(height: 12),
            Text(
              'No image selected',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              'Tap the camera icon to select',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _imageFile!,
          height: 250,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_isProcessing) {
      return const Center(
        child: Column(
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Analyzing image...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results container
        if (_isResultDisplayed) ...[
          _buildContainer(
            title: 'Result',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF1d2630),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  "It's $_predictedLabel",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Cure steps loading
        if (_isCureStepsLoading)
          Column(
            children: const [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 10),
              Text(
                'Suggesting care instructions...',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ],
          ),

        // Cure steps container
        if (_isCureStepsDisplayed && _cureSteps != null)
          _buildContainer(
            title: 'Care Instructions',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1d2630),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _cureSteps!,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContainer({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1d2630),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  @override
  void dispose() {
    _interpreter?.close();
    super.dispose();
  }
}