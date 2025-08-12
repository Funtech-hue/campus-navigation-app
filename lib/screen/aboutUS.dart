import 'package:flutter/material.dart';

class AboutUs extends StatefulWidget {
  const AboutUs({super.key});

  @override
  State<AboutUs> createState() => _AboutUsState();
}

class _AboutUsState extends State<AboutUs> {
  // Track the visibility state for each section
  final Map<String, bool> _visibleMap = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnimatedSection(
              keyName: 'projectName',
              title: 'Project Name',
              text: 'FPE North Campus Navigation System',
            ),
            const SizedBox(height: 16),
            _buildAnimatedSection(
              keyName: 'introduction',
              title: 'Introduction',
              text:
              'This mobile application is designed to help students and visitors '
                  'easily navigate the Federal Polytechnic Ede North Campus. '
                  'It uses GPS and map technology to guide users to buildings, departments, '
                  'and important locations on campus without the need for static maps.',
            ),
            const SizedBox(height: 16),
            _buildAnimatedSection(
              keyName: 'developer',
              title: 'Developed By',
              text: 'BABAYEMI KUDIRAT OLAWUMI\nHC20230100720',
            ),
            const SizedBox(height: 16),
            _buildAnimatedSection(
              keyName: 'supervisor',
              title: 'Supervised By',
              text: 'Mr. Alhaji Kawonise K.A',
            ),
            const SizedBox(height: 16),
            _buildAnimatedSection(
              keyName: 'terms',
              title: 'Terms & Conditions',
              text:
              'This application is intended solely for navigation within the Federal Polytechnic Ede North Campus. '
                  'It should not be used for emergency navigation or as a substitute for official directions. '
                  'Accuracy may vary depending on GPS signal, device capability, and internet availability.',
            ),
            const SizedBox(height: 16),
            _buildAnimatedSection(
              keyName: 'limitations',
              title: 'Limitations',
              text:
              '• Requires internet or GPS for full functionality.\n'
                  '• May have reduced accuracy in areas with poor signal reception.\n'
                  '• Currently limited to the Federal Polytechnic Ede North Campus only.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSection({
    required String keyName,
    required String title,
    required String text,
  }) {
    // default to false (invisible) until tapped
    bool isVisible = _visibleMap[keyName] ?? false;

    return GestureDetector(
      onTap: () {
        setState(() {
          _visibleMap[keyName] = true; // show on tap
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedOpacity(
            opacity: isVisible ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeIn,
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
