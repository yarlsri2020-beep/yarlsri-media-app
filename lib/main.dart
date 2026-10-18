
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:just_audio/just_audio.dart';

const brandRed = Color(0xFFC8102E);
const website = 'https://yarlsrimedia.com';
const newsApi = '$website/news_api.php';

const liveStream =
    'https://5a1178b42cc03.streamlock.net:443/yarlsritv/yarlsritv/playlist.m3u8';

const fmStream =
    'https://de1.streamingpulse.com/stream/yarlsrifm';

const logoAsset = 'assets/images/yarlsri_logo.jpg';

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
}

class NewsItem {
  final int id;
  final String title;
  final String image;
  final String date;
  final String url;

  const NewsItem({
    required this.id,
    required this.title,
    required this.image,
    required this.date,
    required this.url,
  });

  factory NewsItem.fromJson(Map<String, dynamic> json) {
    return NewsItem(
      id: int.tryParse('${json['id']}') ?? 0,
      title: '${json['title'] ?? ''}',
      image: '${json['image'] ?? ''}',
      date: '${json['date'] ?? ''}',
      url: '${json['url'] ?? ''}',
    );
  }
}

Future<List<NewsItem>> fetchLatestNews() async {
  final response = await http
      .get(Uri.parse(newsApi))
      .timeout(const Duration(seconds: 20));

  if (response.statusCode != 200) {
    throw Exception('News server error');
  }

  final data = jsonDecode(utf8.decode(response.bodyBytes));

  if (data is! Map ||
      data['success'] != true ||
      data['news'] is! List) {
    throw Exception('Invalid news data');
  }

  return (data['news'] as List)
      .whereType<Map>()
      .map((item) => NewsItem.fromJson(
            Map<String, dynamic>.from(item),
          ))
      .toList();
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
  late Future<List<NewsItem>> newsFuture;
  Timer? breakingRefreshTimer;

  final titles = const [
    'YARLSRI MEDIA',
    'LIVE TV',
    'LATEST NEWS',
    'VIDEOS',
    'MORE',
  ];

  @override
  void initState() {
    super.initState();
    newsFuture = fetchLatestNews();

    breakingRefreshTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) {
        if (mounted) refreshNews();
      },
    );
  }

  @override
  void dispose() {
    breakingRefreshTimer?.cancel();
    super.dispose();
  }

  void refreshNews() {
    setState(() {
      newsFuture = fetchLatestNews();
    });
  }

  Future<void> pullRefresh() async {
    final future = fetchLatestNews();
    setState(() => newsFuture = future);

    try {
      await future;
    } catch (_) {
      // Error will be displayed in the news area.
    }
  }

  void openNews(String title, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebsiteScreen(
          title: title,
          url: '$website$path',
        ),
      ),
    );
  }

  void openArticle(NewsItem news) {
    final uri = Uri.tryParse(news.url);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'yarlsrimedia.com' ||
        uri.path != '/news_details.php') {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebsiteScreen(
          title: 'YARLSRI NEWS',
          url: news.url,
        ),
      ),
    );
  }

  void openFM() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const FMRadioScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[tab],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (tab == 0 || tab == 2)
            IconButton(
              tooltip: 'Refresh News',
              icon: const Icon(Icons.refresh),
              onPressed: refreshNews,
            ),
        ],
      ),
      body: IndexedStack(
        index: tab,
        children: [
          _home(),
          const LiveTVScreen(),
          _newsPage(),
          const WebsiteScreen(
            title: 'Videos',
            url: '$website/category/videos/',
            embedded: true,
          ),
          _more(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() => tab = value);
        },
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv),
            label: 'Live TV',
          ),
          NavigationDestination(
            icon: Icon(Icons.newspaper_outlined),
            selectedIcon: Icon(Icons.newspaper),
            label: 'News',
          ),
          NavigationDestination(
            icon: Icon(Icons.ondemand_video_outlined),
            selectedIcon: Icon(Icons.ondemand_video),
            label: 'Videos',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _home() {
    return RefreshIndicator(
      onRefresh: pullRefresh,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Image.asset(
                  logoAsset,
                  height: 95,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 8),
                const Text(
                  'உலகத் தமிழர்களின் ஊடகம்',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _breakingNewsBanner(),
          const SizedBox(height: 18),
          const Text(
            'EXPLORE YARLSRI MEDIA',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 1.08,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _shortcut(
                'Live TV',
                Icons.live_tv,
                () => setState(() => tab = 1),
              ),
              _shortcut('FM Radio', Icons.radio, openFM),
              _shortcut(
                'News',
                Icons.newspaper,
                () => setState(() => tab = 2),
              ),
              _shortcut(
                'Videos',
                Icons.play_circle,
                () => setState(() => tab = 3),
              ),
              _shortcut(
                'Sri Lanka',
                Icons.public,
                () => openNews(
                  'Sri Lanka',
                  '/category/sri-lanka/',
                ),
              ),
              _shortcut(
                'Sports',
                Icons.sports_cricket,
                () => openNews(
                  'Sports',
                  '/category/sports/',
                ),
              ),
              _shortcut(
                'More',
                Icons.grid_view,
                () => setState(() => tab = 4),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'LATEST NEWS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: refreshNews,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _newsList(),
          const SizedBox(height: 8),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(
                Icons.live_tv,
                color: brandRed,
                size: 34,
              ),
              title: const Text('YARLSRI TV — LIVE'),
              subtitle: const Text(
                'நேரடி ஒளிபரப்பைப் பார்க்கவும்',
              ),
              trailing: const Icon(Icons.play_arrow),
              onTap: () => setState(() => tab = 1),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.white,
            child: ListTile(
              leading: const Icon(
                Icons.radio,
                color: brandRed,
                size: 34,
              ),
              title: const Text('YARLSRI FM RADIO'),
              subtitle: const Text(
                'நேரடி வானொலியைக் கேட்கவும்',
              ),
              trailing: const Icon(Icons.play_arrow),
              onTap: openFM,
            ),
          ),
        ],
      ),
    );
  }

  Widget _breakingNewsBanner() {
    return FutureBuilder<List<NewsItem>>(
      future: newsFuture,
      builder: (context, snapshot) {
        final items = snapshot.data ?? <NewsItem>[];
        final NewsItem? latest =
            items.isNotEmpty ? items.first : null;

        final isLoading =
            snapshot.connectionState != ConnectionState.done;

        return Material(
          color: brandRed,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: latest == null
                ? refreshNews
                : () => openArticle(latest),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: Colors.white,
                      ),
                      SizedBox(width: 9),
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
                  const SizedBox(height: 9),
                  Text(
                    latest != null
                        ? latest.title
                        : isLoading
                            ? 'சமீபத்திய செய்திகள் ஏற்றப்படுகின்றன...'
                            : snapshot.hasError
                                ? 'செய்திகளைப் பெற முடியவில்லை. மீண்டும் முயற்சிக்க அழுத்துங்கள்.'
                                : 'தற்போது செய்திகள் இல்லை.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (latest != null) ...[
                    const SizedBox(height: 7),
                    const Text(
                      'முழுச் செய்தியைப் படிக்க அழுத்துங்கள்  ›',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _newsPage() {
    return RefreshIndicator(
      onRefresh: pullRefresh,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'YARLSRI MEDIA செய்திகள்',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: refreshNews,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _newsList(),
        ],
      ),
    );
  }

  Widget _newsList() {
    return FutureBuilder<List<NewsItem>>(
      future: newsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState !=
            ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(30),
            child: Center(
              child: CircularProgressIndicator(
                color: brandRed,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.wifi_off,
                    color: brandRed,
                    size: 38,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'செய்திகளை இணைக்க முடியவில்லை.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: refreshNews,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final news = snapshot.data ?? [];

        if (news.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'தற்போது செய்திகள் இல்லை.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        return Column(
          children: news.map(_newsCard).toList(),
        );
      },
    );
  }

  Widget _newsCard(NewsItem news) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openArticle(news),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (news.image.startsWith('https://'))
              Image.network(
                news.image,
                width: double.infinity,
                height: 190,
                fit: BoxFit.cover,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const SizedBox(
                    height: 110,
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                        size: 45,
                      ),
                    ),
                  );
                },
              )
            else
              const SizedBox(
                height: 90,
                child: Center(
                  child: Icon(
                    Icons.newspaper,
                    color: brandRed,
                    size: 42,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 15,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          news.date,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: brandRed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shortcut(
    String title,
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 31, color: brandRed),
            const SizedBox(height: 9),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _more() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Image.asset(
          logoAsset,
          height: 105,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text('உலகத் தமிழர்களின் ஊடகம்'),
        ),
        const SizedBox(height: 20),
        Card(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(
              Icons.radio,
              color: brandRed,
            ),
            title: const Text('YARLSRI FM Radio'),
            trailing: const Icon(Icons.chevron_right),
            onTap: openFM,
          ),
        ),
        ...categories.map(
          (category) => Card(
            color: Colors.white,
            child: ListTile(
              leading: Icon(
                category.icon,
                color: brandRed,
              ),
              title: Text(category.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openNews(
                category.title,
                category.path,
              ),
            ),
          ),
        ),
        Card(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(
              Icons.language,
              color: brandRed,
            ),
            title: const Text('Visit Our Website'),
            onTap: () => openNews(
              'YARLSRI MEDIA',
              '/',
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'YARLSRI MEDIA • Version 1.0.0',
          ),
        ),
      ],
    );
  }
}

class FMRadioScreen extends StatefulWidget {
  const FMRadioScreen({super.key});

  @override
  State<FMRadioScreen> createState() => _FMRadioScreenState();
}

class _FMRadioScreenState extends State<FMRadioScreen> {
  final AudioPlayer player = AudioPlayer();

  bool loading = false;
  bool playing = false;
  String? error;

  @override
  void initState() {
    super.initState();

    player.playerStateStream.listen((state) {
      if (!mounted) return;

      setState(() {
        playing = state.playing;
        loading =
            state.processingState ==
                ProcessingState.loading ||
            state.processingState ==
                ProcessingState.buffering;
      });
    });
  }

  Future<void> startRadio() async {
    if (loading) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      await player.setUrl(fmStream);

      if (!mounted) return;

      player.play();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        error =
            'FM Radio இணைக்க முடியவில்லை. Stream Active ஆனதும் Retry செய்யுங்கள்.';
        loading = false;
      });
    }
  }

  Future<void> toggleRadio() async {
    if (playing) {
      await player.pause();
    } else if (player.audioSource != null) {
      player.play();
    } else {
      await startRadio();
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YARLSRI FM'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          const Center(
            child: CircleAvatar(
              radius: 70,
              backgroundColor: brandRed,
              child: Icon(
                Icons.radio,
                color: Colors.white,
                size: 76,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'YARLSRI FM RADIO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'உலகத் தமிழர்களின் வானொலி',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          const Text(
            '● LIVE RADIO',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: brandRed,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 30),
          Center(
            child: loading
                ? const CircularProgressIndicator(
                    color: brandRed,
                  )
                : FilledButton.icon(
                    onPressed: toggleRadio,
                    icon: Icon(
                      playing
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      playing
                          ? 'Pause Radio'
                          : 'Play Radio',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: brandRed,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                    ),
                  ),
          ),
          if (error != null) ...[
            const SizedBox(height: 20),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: brandRed),
            ),
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                onPressed: startRadio,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ),
          ],
          const SizedBox(height: 30),
          const Text(
            'Radio கேட்க இணைய இணைப்பு தேவை.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
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

    controller = VideoPlayerController.networkUrl(
      Uri.parse(liveStream),
    );

    _start();
  }

  Future<void> _start() async {
    try {
      await controller.initialize();

      if (!mounted) return;

      setState(() => ready = true);
      await controller.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'Live TV இணைக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';
        });
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'YARLSRI TV',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            '● LIVE BROADCAST',
            style: TextStyle(
              color: brandRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          color: Colors.black,
          child: AspectRatio(
            aspectRatio:
                ready && controller.value.aspectRatio > 0
                    ? controller.value.aspectRatio
                    : 16 / 9,
            child: error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
                : ready
                    ? VideoPlayer(controller)
                    : const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      ),
          ),
        ),
        const SizedBox(height: 14),
        if (ready)
          Center(
            child: FilledButton.icon(
              onPressed: () {
                setState(() {
                  if (controller.value.isPlaying) {
                    controller.pause();
                  } else {
                    controller.play();
                  }
                });
              },
              icon: Icon(
                controller.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
              label: Text(
                controller.value.isPlaying
                    ? 'Pause'
                    : 'Play',
              ),
            ),
          ),
        if (error != null)
          Center(
            child: TextButton.icon(
              onPressed: () {
                setState(() {
                  error = null;
                  ready = false;
                });
                _start();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        const SizedBox(height: 18),
        const Text(
          'YARLSRI TV நேரடி ஒளிபரப்பு',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'ஒளிபரப்பைப் பார்க்க இணைய இணைப்பு தேவை.',
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class WebsiteScreen extends StatefulWidget {
  final String title;
  final String url;
  final bool embedded;

  const WebsiteScreen({
    super.key,
    required this.title,
    required this.url,
    this.embedded = false,
  });

  @override
  State<WebsiteScreen> createState() =>
      _WebsiteScreenState();
}

class _WebsiteScreenState extends State<WebsiteScreen> {
  late final WebViewController controller;

  bool loading = true;

  @override
  void initState() {
    super.initState();

    controller = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
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
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        WebViewWidget(controller: controller),
        if (loading)
          const Center(
            child: CircularProgressIndicator(
              color: brandRed,
            ),
          ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.reload(),
          ),
        ],
      ),
      body: content,
    );
  }
}
