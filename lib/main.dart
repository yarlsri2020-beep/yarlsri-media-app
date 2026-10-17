
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
          seedColor: const Color(0xFFC8102E),
        ),
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

class MediaHomePage extends StatelessWidget {
  const MediaHomePage({super.key});

  void openCategory(BuildContext context, NewsCategory category) {
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
        backgroundColor: const Color(0xFFC8102E),
        foregroundColor: Colors.white,
        title: const Text(
          'YARLSRI MEDIA',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            color: const Color(0xFF181818),
            child: const Column(
              children: [
                Text(
                  'யாழ்ஸ்ரீ மீடியா',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'உலகத் தமிழர்களின் ஊடகம்',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: categories.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.45,
              ),
              itemBuilder: (context, index) {
                final category = categories[index];
                return Card(
                  elevation: 2,
                  color: Colors.white,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => openCategory(context, category),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category.icon,
                          size: 34,
                          color: const Color(0xFFC8102E),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          category.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          NavigationDestination(
            icon: Icon(Icons.play_circle),
            label: 'Videos',
          ),
        ],
        onDestinationSelected: (index) {
          if (index == 1) {
            openCategory(context, categories[0]);
          } else if (index == 2) {
            openCategory(context, categories[6]);
          }
        },
      ),
    );
  }
}

class NewsPage extends StatefulWidget {
  final NewsCategory category;

  const NewsPage({super.key, required this.category});

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
          onPageFinished: (_) {
            if (mounted) setState(() => loading = false);
          },
        ),
      )
      ..loadRequest(
        Uri.parse(
          'https://yarlsrimedia.com${widget.category.path}',
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.name),
        backgroundColor: const Color(0xFFC8102E),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: controller),
          if (loading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
