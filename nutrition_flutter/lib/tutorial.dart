import 'package:flutter/material.dart';
import 'home.dart';
import 'user_database.dart';

const Color kGreen = Color(0xFF43A047); // Main green
const Color kLightGreen = Color(0xFFF4FFF4); // Background

class TutorialScreen extends StatefulWidget {
  final String usernameOrEmail;
  const TutorialScreen({super.key, required this.usernameOrEmail});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<TutorialPage> _pages = [
    TutorialPage(
      title: 'Welcome to Nutritionist App',
      description:
          'Your personal nutrition companion for a healthier lifestyle.',
      image: 'design/logo.png',
    ),
    TutorialPage(
      title: 'Track Your Meals',
      description:
          'Log your meals and snacks with ease. Get detailed nutrition insights for everything you eat.',
      image: 'design/logo.png',
    ),
    TutorialPage(
      title: 'Monitor Progress',
      description:
          'Track your nutrition goals and see your progress over time with beautiful charts and insights.',
      image: 'design/logo.png',
    ),
    TutorialPage(
      title: 'Set Your Goals',
      description:
          'Set personalized nutrition goals and get recommendations tailored to your needs.',
      image: 'design/logo.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onGetStarted() async {
    // Mark tutorial as seen
    await UserDatabase().markTutorialAsSeen(widget.usernameOrEmail);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomePage(usernameOrEmail: widget.usernameOrEmail),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kLightGreen,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              return _buildPage(_pages[index]);
            },
          ),
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => _buildDot(index),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child:
                      _currentPage == _pages.length - 1
                          ? ElevatedButton(
                            onPressed: _onGetStarted,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 4,
                              shadowColor: kGreen.withAlpha(
                                (0.3 * 255).toInt(),
                              ),
                            ),
                            child: const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          : Column(
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeIn,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kGreen,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  elevation: 4,
                                  shadowColor: kGreen.withAlpha(
                                    (0.3 * 255).toInt(),
                                  ),
                                ),
                                child: const Text(
                                  'Next',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(TutorialPage page) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(page.image, width: 180, height: 180),
          const SizedBox(height: 40),
          Text(
            page.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: kGreen,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            page.description,
            style: const TextStyle(fontSize: 16, color: kGreen, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color:
            _currentPage == index
                ? kGreen
                : kGreen.withAlpha((0.2 * 255).toInt()),
      ),
    );
  }
}

class TutorialPage {
  final String title;
  final String description;
  final String image;

  TutorialPage({
    required this.title,
    required this.description,
    required this.image,
  });
}
