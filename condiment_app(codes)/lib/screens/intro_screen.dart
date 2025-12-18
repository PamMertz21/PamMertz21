import 'package:flutter/material.dart';
import 'classifier_home.dart';

const Map<String, String> condimentDescriptions = {
  'Ketchup': 'A sweet and tangy tomato-based condiment. Perfect for fries, burgers, and dipping.',
  'Mayonnaise': 'Creamy and savory spread made from eggs and oil. Great for sandwiches and dressings.',
  'Mustard': 'Sharp and zesty condiment with a bold flavor. Ideal for hot dogs and meats.',
  'Soy Sauce': 'Umami-rich Asian staple made from fermented soybeans. Essential for Asian cuisine.',
  'Vinegar': 'Tangy and acidic condiment. Adds brightness to salads, pickles, and marinades.',
  'Hot Sauce': 'Spicy and fiery condiment. Brings heat and flavor to any dish.',
  'Salt': 'Essential mineral seasoning. Enhances flavor in every cuisine.',
  'Pepper': 'Warm and peppery spice. A classic seasoning for all dishes.',
  'Fish Sauce': 'Pungent and aromatic Asian sauce. Adds deep umami to Southeast Asian dishes.',
  'Garlic Sauce': 'Bold and aromatic creamy sauce. Perfect for dipping and marinades.',
};

/// Optional images shown in the "Our Condiments" cards.
///
/// Place the image files under `asset/` and update these paths to match.
const Map<String, String> condimentImages = {
  'Ketchup': 'asset/ketchup.jpg',
  'Mayonnaise': 'asset/mayonnaise.jpg',
  'Mustard': 'asset/mustard.jpg',
  'Soy Sauce': 'asset/soy sauce.jpg',
  'Vinegar': 'asset/vinegar.jpg',
  'Hot Sauce': 'asset/hot sauce.jpg',
  'Salt': 'asset/salt.jpg',
  'Pepper': 'asset/pepper.jpg',
  'Fish Sauce': 'asset/fish sauce.webp',
  'Garlic Sauce': 'asset/garlic sauce.jpg',
};

class IntroScreen extends StatefulWidget {
  const IntroScreen({Key? key}) : super(key: key);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this);
    _slideController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Background image with overlay for readability
          Positioned.fill(
            child: Stack(
              children: [
                Image.asset(
                  'asset/bg.jpg',
                  fit: BoxFit.cover,
                ),
                Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              ],
            ),
          ),

          // Content layer
          SafeArea(
            child: Column(
              children: [
                // Top section: Title + Subtitle
                SizedBox(height: h * 0.08),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        Text(
                          'Condiment',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 48,
                                letterSpacing: 0.5,
                              ),
                        ),
                        Text(
                          'Classification',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                color: const Color(0xFFFF6B35),
                                fontWeight: FontWeight.w700,
                                fontSize: 48,
                                letterSpacing: 0.5,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Identify condiments with AI-powered image recognition',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[400],
                                fontSize: 14,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // Middle section: "Let's Scan" button
                Expanded(
                  child: Center(
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ClassifierHome()),
                            );
                          },
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [const Color(0xFFFF6B35), const Color(0xFFE83E2B)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFF6B35).withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ClassifierHome()),
                                  );
                                },
                                customBorder: const CircleBorder(),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt, size: 48, color: Colors.white),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Let's Scan",
                                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom section: Condiment list
                Container(
                  // Slightly taller to avoid overflow when images are present
                  height: h * 0.30,
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        child: Text(
                          'Our Condiments',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          scrollDirection: Axis.horizontal,
                          itemCount: condimentDescriptions.length,
                          itemBuilder: (context, idx) {
                            final condiments = condimentDescriptions.entries.toList();
                            final entry = condiments[idx];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: CondimentCard(
                                name: entry.key,
                                description: entry.value,
                              ),
                            );
                          },
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
}

class CondimentCard extends StatelessWidget {
  final String name;
  final String description;

  const CondimentCard({
    Key? key,
    required this.name,
    required this.description,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Map condiment name to a representative color
    final colorMap = {
      'Ketchup': const Color(0xFFCC2E2E),
      'Mayonnaise': const Color(0xFFFFF8DC),
      'Mustard': const Color(0xFFFFD700),
      'Soy Sauce': const Color(0xFF2D2D2D),
      'Vinegar': const Color(0xFF8B4513),
      'Hot Sauce': const Color(0xFFFF4500),
      'Salt': const Color(0xFFF5F5F5),
      'Pepper': const Color(0xFF1C1C1C),
      'Fish Sauce': const Color(0xFF8B6914),
      'Garlic Sauce': const Color(0xFFF5DEB3),
    };

    final color = colorMap[name] ?? Colors.grey;
    final isDark = color.computeLuminance() < 0.5;
    final imagePath = condimentImages[name];

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showDetails(context, color, isDark, imagePath),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: color.withOpacity(0.95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imagePath != null) ...[
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if asset is missing
                      return Container(
                        color: Colors.black12,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isDark ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[200] : Colors.black87,
                          height: 1.3,
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, Color color, bool isDark, String? imagePath) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.45,
      maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
                  colors: [
                color.withOpacity(0.98),
                color.withOpacity(0.92),
                Colors.white,
                  ],
              stops: const [0.0, 0.45, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.restaurant_menu_rounded,
                                        size: 16, color: Colors.white.withOpacity(0.95)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Our condiment spotlight',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: Colors.white.withOpacity(0.95),
                                            letterSpacing: 0.2,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                name,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.3,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (imagePath != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                imagePath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.black12,
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.grey[500],
                                    ),
                                  );
                                },
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.45),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Text(
                          description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[800],
                                height: 1.5,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
