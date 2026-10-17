
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const brandRed = Color(0xFFC8102E);
const website = 'https://yarlsrimedia.com';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YarlsriMediaApp());
}

class YarlsriMediaApp extends StatelessWidget {
  const YarlsriMediaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'YARLSRI MEDIA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandRed,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        useMaterial3: true,
      ),
      home: const MediaHomePage(),
    );
  }
}

class NewsCategory {
  final String name;
  final String path;
  final IconData icon;

  const NewsCategory(this.name, this.path, this.icon);
}

const categories = [
  NewsCategory('Latest News', '/', Icons.newspaper),
  NewsCategory('Sri Lanka', '/category/sri-lanka/', Icons.public),
  NewsCategory('India', '/category/india/', Icons.flag),
  NewsCategory('World', '/category/world/', Icons.language),
  NewsCategory('Cinema', '/category/cinema/', Icons.movie),
  NewsCategory('Sports', '/category/sports/', Icons.sports_cricket),
  NewsCategory('Videos', '/category/videos/', Icons.play_circle),
  NewsCategory('TV & Radio', '/category/tv-radio/', Icons.live_tv),
];

class MediaHomePage extends StatefulWidget {
  const MediaHomePage({super.key});

  @override
  State<MediaHomePage> createState() => _MediaHomePageState();
}

class _MediaHomePageState extends State<MediaHomePage> {
  int selectedTab = 0;

  late final WebViewController homeController;
  bool newsLoading = true;

  @override
  void initState() {
    super.initState();

    homeController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => newsLoading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => newsLoading = false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(website));
  }

  void openCategory(NewsCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NewsPage(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: brandRed,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'YARLSRI MEDIA',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh News',
            onPressed: () => homeController.reload(),
          ),
        ],
      ),
      body: selectedTab == 0
          ? buildHome()
          : selectedTab == 1
              ? buildCategories()
              : buildAbout(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() => selectedTab = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            label: 'About',
          ),
        ],
      ),
    );
  }

  Widget buildHome() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              Image.asset(
                'assets/images/yarlsri_logo.jpg',
                height: 75,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 4),
              const Text(
                'உலகத் தமிழர்களின் ஊடகம்',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          color: brandRed,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 9,
          ),
          child: const Row(
            children: [
              Icon(
                Icons.circle,
                color: Colors.white,
                size: 10,
              ),
              SizedBox(width: 8),
              Text(
                'BREAKING NEWS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Icon(
                Icons.bolt,
                color: Colors.white,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 106,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(10),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () => openCategory(category),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 105,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.black12,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category.icon,
                          color: brandRed,
                          size: 28,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          category.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          child: Row(
            children: [
              Icon(Icons.newspaper, color: brandRed),
              SizedBox(width: 8),
              Text(
                'LATEST NEWS',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              WebViewWidget(controller: homeController),
              if (newsLoading)
                const Center(
                  child: CircularProgressIndicator(
                    color: brandRed,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCategories() {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: categories.length,
      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];

        return Card(
          color: Colors.white,
          child: InkWell(
            onTap: () => openCategory(category),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  category.icon,
                  size: 38,
                  color: brandRed,
                ),
                const SizedBox(height: 12),
                Text(
                  category.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildAbout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/yarlsri_logo.jpg',
              height: 140,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 18),
            const Text(
              'YARLSRI MEDIA',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: brandRed,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'உலகத் தமிழர்களின் ஊடகம்',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            const Text(
              'இலங்கை, இந்தியா, உலகம், சினிமா, '
              'விளையாட்டு மற்றும் காணொளிச் '
              'செய்திகளை அறிந்துகொள்ளுங்கள்.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => openCategory(categories[0]),
              icon: const Icon(Icons.language),
              label: const Text('Visit Our Website'),
            ),
            const SizedBox(height: 24),
            const Text('Version 1.0.0'),
          ],
        ),
      ),
    );
  }
}

class NewsPage extends StatefulWidget {
  final NewsCategory category;

  const NewsPage({
    super.key,
    required this.category,
  });

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  late final WebViewController controller;
  bool loading = true;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() => loading = true);
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() => loading = false);
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse('$website${widget.category.path}'),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        backgroundColor: brandRed,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (loading)
            const Center(
              child: CircularProgressIndicator(
                color: brandRed,
              ),
            ),
        ],
      ),
    );
  }
}
