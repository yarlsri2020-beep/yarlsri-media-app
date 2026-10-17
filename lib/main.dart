import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

const brandRed = Color(0xFFC8102E);
const website = 'https://yarlsrimedia.com';
const liveStream = 'https://5a1178b42cc03.streamlock.net:443/yarlsritv/yarlsritv/playlist.m3u8';
const logoAsset = 'assets/images/yarlsri_logo.jpg';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YarlsriMediaApp());
}

class YarlsriMediaApp extends StatelessWidget {
  const YarlsriMediaApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'YARLSRI MEDIA',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: brandRed),
          scaffoldBackgroundColor: const Color(0xFFF7F7F7),
          appBarTheme: const AppBarTheme(
            backgroundColor: brandRed,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
        ),
        home: const MainScreen(),
      );
}

class NewsCategory {
  final String title;
  final String path;
  final IconData icon;
  const NewsCategory(this.title, this.path, this.icon);
}

const categories = <NewsCategory>[
  NewsCategory('Sri Lanka', '/category/sri-lanka/', Icons.public),
  NewsCategory('India', '/category/india/', Icons.flag),
  NewsCategory('World', '/category/world/', Icons.language),
  NewsCategory('Cinema', '/category/cinema/', Icons.movie),
  NewsCategory('Sports', '/category/sports/', Icons.sports_cricket),
  NewsCategory('Videos', '/category/videos/', Icons.play_circle),
  NewsCategory('TV & Radio', '/category/tv-radio/', Icons.live_tv),
];

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int tab = 0;
  final titles = const ['YARLSRI MEDIA', 'LIVE TV', 'LATEST NEWS', 'VIDEOS', 'MORE'];

  void openNews(String title, String path) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => WebsiteScreen(title: title, url: '$website$path'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[tab], style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: IndexedStack(
        index: tab,
        children: [
          _home(),
          const LiveTVScreen(),
          const WebsiteScreen(title: 'Latest News', url: website, embedded: true),
          const WebsiteScreen(title: 'Videos', url: '$website/category/videos/', embedded: true),
          _more(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) => setState(() => tab = value),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.live_tv_outlined), selectedIcon: Icon(Icons.live_tv), label: 'Live TV'),
          NavigationDestination(icon: Icon(Icons.newspaper_outlined), selectedIcon: Icon(Icons.newspaper), label: 'News'),
          NavigationDestination(icon: Icon(Icons.ondemand_video_outlined), selectedIcon: Icon(Icons.ondemand_video), label: 'Videos'),
          NavigationDestination(icon: Icon(Icons.menu), label: 'More'),
        ],
      ),
    );
  }

  Widget _home() => ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Image.asset(logoAsset, height: 95, fit: BoxFit.contain),
              const SizedBox(height: 8),
              const Text('உலகத் தமிழர்களின் ஊடகம்', style: TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: brandRed, borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.circle, size: 10, color: Colors.white),
              SizedBox(width: 9),
              Text('BREAKING NEWS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Spacer(),
              Icon(Icons.bolt, color: Colors.white),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('EXPLORE YARLSRI MEDIA', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 1.08,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _shortcut('Live TV', Icons.live_tv, () => setState(() => tab = 1)),
              _shortcut('News', Icons.newspaper, () => setState(() => tab = 2)),
              _shortcut('Videos', Icons.play_circle, () => setState(() => tab = 3)),
              _shortcut('Sri Lanka', Icons.public, () => openNews('Sri Lanka', '/category/sri-lanka/')),
              _shortcut('Sports', Icons.sports_cricket, () => openNews('Sports', '/category/sports/')),
              _shortcut('More', Icons.grid_view, () => setState(() => tab = 4)),
            ],
          ),
          const SizedBox(height: 22),
          const Text('LATEST NEWS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.language, color: brandRed, size: 34),
              title: const Text('YARLSRI MEDIA செய்திகள்'),
              subtitle: const Text('சமீபத்திய செய்திகள் மற்றும் படங்களைப் பார்க்கவும்'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => setState(() => tab = 2),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.live_tv, color: brandRed, size: 34),
              title: const Text('YARLSRI TV — LIVE'),
              subtitle: const Text('நேரடி ஒளிபரப்பைப் பார்க்கவும்'),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => setState(() => tab = 1),
            ),
          ),
        ],
      );

  Widget _shortcut(String title, IconData icon, VoidCallback onTap) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 31, color: brandRed),
            const SizedBox(height: 9),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),
      );

  Widget _more() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Image.asset(logoAsset, height: 105, fit: BoxFit.contain),
          const SizedBox(height: 12),
          const Center(child: Text('உலகத் தமிழர்களின் ஊடகம்')),
          const SizedBox(height: 20),
          ...categories.map((category) => Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(category.icon, color: brandRed),
                  title: Text(category.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openNews(category.title, category.path),
                ),
              )),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(Icons.language, color: brandRed),
              title: const Text('Visit Our Website'),
              onTap: () => openNews('YARLSRI MEDIA', '/'),
            ),
          ),
          const SizedBox(height: 18),
          const Center(child: Text('YARLSRI MEDIA • Version 1.0.0')),
        ],
      );
}

class LiveTVScreen extends StatefulWidget {
  const LiveTVScreen({super.key});
  @override
  State<LiveTVScreen> createState() => _LiveTVScreenState();
}

class _LiveTVScreenState extends State<LiveTVScreen> {
  late final VideoPlayerController controller;
  bool ready = false;
  String? error;

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(liveStream));
    _start();
  }

  Future<void> _start() async {
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() => ready = true);
      await controller.play();
    } catch (_) {
      if (mounted) setState(() => error = 'Live TV இணைக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('YARLSRI TV', textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Center(child: Text('● LIVE BROADCAST', style: TextStyle(color: brandRed, fontWeight: FontWeight.bold))),
          const SizedBox(height: 16),
          Container(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: ready && controller.value.aspectRatio > 0 ? controller.value.aspectRatio : 16 / 9,
              child: error != null
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(error!, textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white)),
                    ))
                  : ready
                      ? VideoPlayer(controller)
                      : const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 14),
          if (ready)
            Center(child: FilledButton.icon(
              onPressed: () => setState(() {
                controller.value.isPlaying ? controller.pause() : controller.play();
              }),
              icon: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(controller.value.isPlaying ? 'Pause' : 'Play'),
            )),
          if (error != null)
            Center(child: TextButton.icon(
              onPressed: () => setState(() {
                error = null;
                ready = false;
                _start();
              }),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            )),
          const SizedBox(height: 18),
          const Text('YARLSRI TV நேரடி ஒளிபரப்பு', textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('ஒளிபரப்பைப் பார்க்க இணைய இணைப்பு தேவை.', textAlign: TextAlign.center),
        ],
      );
}

class WebsiteScreen extends StatefulWidget {
  final String title;
  final String url;
  final bool embedded;
  const WebsiteScreen({super.key, required this.title, required this.url, this.embedded = false});
  @override
  State<WebsiteScreen> createState() => _WebsiteScreenState();
}

class _WebsiteScreenState extends State<WebsiteScreen> {
  late final WebViewController controller;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) { if (mounted) setState(() => loading = true); },
        onPageFinished: (_) { if (mounted) setState(() => loading = false); },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(children: [
      WebViewWidget(controller: controller),
      if (loading) const Center(child: CircularProgressIndicator(color: brandRed)),
    ]);
    if (widget.embedded) return content;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => controller.reload())],
      ),
      body: content,
    );
  }
}
