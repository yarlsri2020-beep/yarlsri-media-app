import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';

const brandRed = Color(0xFFC8102E);
const brandBlue = Color(0xFF0644B8);
const brandDarkBlue = Color(0xFF07318B);
const website = 'https://yarlsrimedia.com';
const newsApi = '$website/news_api.php';

const liveStream =
    'https://5a1178b42cc03.streamlock.net:443/yarlsritv/yarlsritv/playlist.m3u8';

const fmStream =
    'https://de1.streamingpulse.com/stream/yarlsrifm';

const logoAsset = 'assets/images/yarlsri_logo.jpg';
const fmLogoAsset = 'assets/images/yarlsri_fm_logo.jpg';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.yarlsrimedia.yarlsri_media.radio',
      androidNotificationChannelName: 'YARLSRI FM Radio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: false,
    );
    runApp(const YarlsriMediaApp());
  } catch (error, stackTrace) {
    // Do not silently start an app whose background radio service failed.
    debugPrint('Background audio initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'FM background audio setup failed.\n\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    ));
  }
}

class YarlsriMediaApp extends StatefulWidget {
  const YarlsriMediaApp({super.key});

  @override
  State<YarlsriMediaApp> createState() => _YarlsriMediaAppState();
}

class _YarlsriMediaAppState extends State<YarlsriMediaApp> {
  final AppLinks _appLinks = AppLinks();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingUrl;
  String? _activeUrl;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleNewsLink,
      onError: (Object error) {},
    );
    _checkInitialLink();
  }

  Future<void> _checkInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null && mounted) _handleNewsLink(uri);
    } catch (_) {
      // The app can still open normally when no initial link is available.
    }
  }

  void _handleNewsLink(Uri uri) {
    final id = int.tryParse(uri.queryParameters['id'] ?? '');
    if (uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'yarlsrimedia.com' ||
        uri.path != '/news_details.php' ||
        id == null ||
        id <= 0) {
      return;
    }

    final url = uri.toString();
    if (_pendingUrl == url || _activeUrl == url) return;
    _pendingUrl = url;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingUrl != url) return;
      final navigator = _navigatorKey.currentState;
      if (navigator == null) {
        _pendingUrl = null;
        return;
      }
      _pendingUrl = null;
      _activeUrl = url;
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => WebsiteScreen(
            title: 'YARLSRI NEWS',
            url: url,
            shareTitle: 'YARLSRI NEWS',
          ),
        ),
      ).then((_) {
        if (_activeUrl == url) _activeUrl = null;
      });
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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

  final data = jsonDecode(
    utf8.decode(response.bodyBytes),
  );

  if (data is! Map ||
      data['success'] != true ||
      data['news'] is! List) {
    throw Exception('Invalid news data');
  }

  return (data['news'] as List)
      .whereType<Map>()
      .map(
        (item) => NewsItem.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
      .toList();
}

class NewsCategory {
  final String title;
  final String path;
  final IconData icon;

  const NewsCategory(
    this.title,
    this.path,
    this.icon,
  );
}

const categories = <NewsCategory>[
  NewsCategory(
    'Sri Lanka',
    '/srilanka',
    Icons.public,
  ),
  NewsCategory(
    'India',
    '/category/india/',
    Icons.flag,
  ),
  NewsCategory(
    'World',
    '/category/world/',
    Icons.language,
  ),
  NewsCategory(
    'Cinema',
    '/category/cinema/',
    Icons.movie,
  ),
  NewsCategory(
    'Sports',
    '/category/sports/',
    Icons.sports_cricket,
  ),
  NewsCategory(
    'Videos',
    '/category/videos/',
    Icons.play_circle,
  ),
  NewsCategory(
    'TV & Radio',
    '/category/tv-radio/',
    Icons.live_tv,
  ),
];

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() =>
      _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int tab = 0;
  String selectedLanguage = 'ta';

  static const languageNames = <String, String>{
    'ta': '🇱🇰 தமிழ்', 'en': '🇬🇧 ENGLISH',
    'si': '🇱🇰 සිංහල', 'hi': '🇮🇳 हिन्दी',
    'fr': '🇫🇷 FRANÇAIS', 'es': '🇪🇸 ESPAÑOL',
    'it': '🇮🇹 ITALIANO', 'de': '🇩🇪 DEUTSCH',
    'ar': '🇸🇦 العربية', 'ml': '🇮🇳 മലയാളം',
  };

  String tr(String key) {
    const translations = <String, Map<String, String>>{
      'Home': {'ta':'முகப்பு','en':'Home','si':'මුල් පිටුව','hi':'होम','fr':'Accueil','es':'Inicio','it':'Home','de':'Startseite','ar':'الرئيسية','ml':'ഹോം'},
      'News': {'ta':'செய்திகள்','en':'News','si':'පුවත්','hi':'समाचार','fr':'Actualités','es':'Noticias','it':'Notizie','de':'Nachrichten','ar':'الأخبار','ml':'വാർത്തകൾ'},
      'Live TV': {'ta':'நேரலை TV','en':'Live TV','si':'සජීවී TV','hi':'लाइव TV','fr':'TV en direct','es':'TV en vivo','it':'TV in diretta','de':'Live-TV','ar':'بث مباشر','ml':'ലൈവ് TV'},
      'Videos': {'ta':'வீடியோக்கள்','en':'Videos','si':'වීඩියෝ','hi':'वीडियो','fr':'Vidéos','es':'Vídeos','it':'Video','de':'Videos','ar':'فيديو','ml':'വീഡിയോകൾ'},
      'More': {'ta':'மேலும்','en':'More','si':'තවත්','hi':'अधिक','fr':'Plus','es':'Más','it':'Altro','de':'Mehr','ar':'المزيد','ml':'കൂടുതൽ'},
      'Sri Lanka': {'ta':'இலங்கை','en':'Sri Lanka','si':'ශ්‍රී ලංකා','hi':'श्रीलंका','fr':'Sri Lanka','es':'Sri Lanka','it':'Sri Lanka','de':'Sri Lanka','ar':'سريلانكا','ml':'ശ്രീലങ്ക'},
      'World': {'ta':'உலகம்','en':'World','si':'ලෝකය','hi':'विश्व','fr':'Monde','es':'Mundo','it':'Mondo','de':'Welt','ar':'العالم','ml':'ലോകം'},
      'Settings': {'ta':'அமைப்புகள்','en':'Settings','si':'සැකසුම්','hi':'सेटिंग्स','fr':'Paramètres','es':'Ajustes','it':'Impostazioni','de':'Einstellungen','ar':'الإعدادات','ml':'ക്രമീകരണങ്ങൾ'},
    };
    return translations[key]?[selectedLanguage] ?? key;
  }

  void openTopCategory(String name, String path) {
    if (name == 'Home') { setState(() => tab = 0); return; }
    openNews(tr(name), path);
  }

  Widget _topMenu() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        color: brandDarkBlue,
        height: 52,
        child: Row(children: [
          Expanded(child: ListView(scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            children: [
              _topTab('Home', '/', Icons.home),
              _topTab('Sri Lanka', '/srilanka', Icons.article_outlined),
              _topTab('World', '/category/world/', Icons.public),
              _topTab('Tamil Nadu', '/category/india/', Icons.account_balance_outlined),
            ],
          )),
          PopupMenuButton<String>(
            tooltip: 'More categories',
            onSelected: (value) {
              if (value == 'more') { setState(() => tab = 4); return; }
              if (value == 'fm') { openFM(); return; }
              openNews(value, value == 'sports' ? '/category/sports/' :
                value == 'cinema' ? '/category/cinema/' : '/category/videos/');
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'sports', child: Text('Sports')),
              PopupMenuItem(value: 'cinema', child: Text('Cinema')),
              PopupMenuItem(value: 'videos', child: Text('Videos')),
              PopupMenuItem(value: 'fm', child: Text('FM Radio')),
              PopupMenuItem(value: 'more', child: Text('More / Settings')),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                Text('More', style: TextStyle(color: Colors.white,
                  fontWeight: FontWeight.bold)),
                Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ]),
            ),
          ),
        ]),
      ),
      Container(
        color: Colors.white,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: brandRed,
              borderRadius: BorderRadius.circular(9)),
            child: const Text('BREAKING', style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 9),
          const Expanded(child: Text('YARLSRI MEDIA • Latest News',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
          PopupMenuButton<String>(
            tooltip: 'Choose language',
            onSelected: (value) => setState(() => selectedLanguage = value),
            itemBuilder: (_) => languageNames.entries.map((entry) =>
              PopupMenuItem<String>(value: entry.key,
                child: Row(children: [
                  Expanded(child: Text(entry.value)),
                  if (entry.key == selectedLanguage)
                    const Icon(Icons.check, color: Colors.green),
                ]),
              )).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueGrey.shade200),
                borderRadius: BorderRadius.circular(22)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(languageNames[selectedLanguage]!.split(' ').first,
                  style: const TextStyle(fontSize: 21)),
                const SizedBox(width: 4),
                Text(selectedLanguage.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.keyboard_arrow_down, size: 19),
              ]),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _topTab(String name, String path, IconData icon) {
    return TextButton.icon(
      onPressed: () => openTopCategory(name, path),
      icon: Icon(icon, size: 17, color: Colors.white),
      label: Text(tr(name), style: const TextStyle(color: Colors.white,
        fontWeight: FontWeight.w600)),
    );
  }

  late Future<List<NewsItem>> newsFuture;
  Timer? breakingRefreshTimer;
  Timer? slideshowTimer;
  List<NewsItem> slideItems = [];
  final PageController slideshowController = PageController();
  int slideIndex = 0;
  String searchQuery = '';
  bool savedOnly = false;
  final Set<int> savedIds = <int>{};
  final TextEditingController searchController = TextEditingController();

  Future<void> loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      savedIds.addAll((prefs.getStringList('saved_news_ids') ?? [])
        .map(int.tryParse).whereType<int>());
    });
  }

  Future<void> toggleSaved(NewsItem item) async {
    setState(() {
      if (!savedIds.add(item.id)) savedIds.remove(item.id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_news_ids',
      savedIds.map((id) => id.toString()).toList());
  }


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
    loadSaved();
    slideshowTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || tab != 0 || !slideshowController.hasClients) return;
      final news = slideItems;
      if (news.length < 2) return;
      final next = (slideIndex + 1) % news.length;
      slideshowController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });

    breakingRefreshTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) {
        if (mounted) {
          refreshNews();
        }
      },
    );
  }

  @override
  void dispose() {
    breakingRefreshTimer?.cancel();
    slideshowTimer?.cancel();
    slideshowController.dispose();
    searchController.dispose();
    super.dispose();
  }

  void refreshNews() {
    setState(() {
      newsFuture = fetchLatestNews();
    });
  }

  Future<void> pullRefresh() async {
    final future = fetchLatestNews();

    setState(() {
      newsFuture = future;
    });

    try {
      await future;
    } catch (_) {
      // FutureBuilder shows the error.
    }
  }

  Future<void> shareNews(NewsItem news) async {
    final uri = Uri.tryParse(news.url);

    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'yarlsrimedia.com' ||
        uri.path != '/news_details.php') {
      return;
    }

    final text =
        '${news.title}\n\n'
        '${news.url}\n\n'
        'YARLSRI MEDIA';

    try {
      await Share.share(
        text,
        subject: news.title,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'செய்தியைப் பகிர முடியவில்லை.',
          ),
        ),
      );
    }
  }

  void openNews(
    String title,
    String path,
  ) {
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
          shareTitle: news.title,
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
        backgroundColor: brandDarkBlue,
        titleSpacing: 0,
        leading: PopupMenuButton<String>(
          icon: const Icon(Icons.menu, color: Colors.white),
          tooltip: tr('Settings'),
          onSelected: (value) {
            if (value == 'home') { setState(() => tab = 0); }
            if (value == 'more') { setState(() => tab = 4); }
            if (value == 'fm') { openFM(); }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'home', child: Text(tr('Home'))),
            const PopupMenuItem(value: 'fm', child: Text('FM Radio')),
            PopupMenuItem(value: 'more', child: Text(tr('Settings'))),
          ],
        ),
        title: Row(children: [
          Image.asset(logoAsset, height: 35, width: 44, fit: BoxFit.contain),
          const SizedBox(width: 7),
          const Expanded(child: Text('YARLSRI MEDIA',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold,
              color: Colors.white))),
        ]),
        actions: [
          IconButton(
            tooltip: 'Refresh News',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: refreshNews,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: _topMenu(),
        ),
      ),
      body: IndexedStack(
        index: tab,
        children: [
          _home(),
          const LiveTVScreen(),
          const FMRadioScreen(),
          _newsPage(),
          _more(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: brandDarkBlue,
        indicatorColor: brandBlue,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: Colors.white, fontSize: 11,
            fontWeight: FontWeight.w600)),
        selectedIndex: tab,
        onDestinationSelected: (value) {
          setState(() {
            tab = value;
          });
        },
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Colors.white),
            selectedIcon: Icon(Icons.home, color: Colors.white),
            label: tr('Home')),
          const NavigationDestination(
            icon: Icon(Icons.live_tv_outlined, color: Colors.white),
            selectedIcon: Icon(Icons.live_tv, color: Colors.white),
            label: 'Live TV'),
          const NavigationDestination(
            icon: Icon(Icons.radio_outlined, color: Colors.white),
            selectedIcon: Icon(Icons.radio, color: Colors.white),
            label: 'FM Radio'),
          NavigationDestination(
            icon: const Icon(Icons.newspaper_outlined, color: Colors.white),
            selectedIcon: const Icon(Icons.newspaper, color: Colors.white),
            label: tr('News')),
          NavigationDestination(
            icon: const Icon(Icons.grid_view, color: Colors.white),
            selectedIcon: const Icon(Icons.grid_view, color: Colors.white),
            label: tr('More')),
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
          _newsSlideshow(),
          const SizedBox(height: 14),
          _quickAccessRow(),
          const SizedBox(height: 18),
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
              title: const Text(
                'YARLSRI TV — LIVE',
              ),
              subtitle: const Text(
                'நேரடி ஒளிபரப்பைப் பார்க்கவும்',
              ),
              trailing: const Icon(
                Icons.play_arrow,
              ),
              onTap: () {
                setState(() => tab = 1);
              },
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
              title: const Text(
                'YARLSRI FM RADIO',
              ),
              subtitle: const Text(
                'நேரடி வானொலியைக் கேட்கவும்',
              ),
              trailing: const Icon(
                Icons.play_arrow,
              ),
              onTap: openFM,
            ),
          ),
        ],
      ),
    );
  }

  Widget _newsSlideshow() {
    return FutureBuilder<List<NewsItem>>(
      future: newsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
          slideItems = snapshot.data!.take(5).toList();
        }
        if (slideItems.isEmpty) {
          return Container(
            height: 210,
            decoration: BoxDecoration(color: brandDarkBlue,
              borderRadius: BorderRadius.circular(16)),
            child: Center(child: snapshot.hasError
              ? TextButton(onPressed: refreshNews,
                  child: const Text('Retry news', style: TextStyle(color: Colors.white)))
              : const CircularProgressIndicator(color: Colors.white)),
          );
        }
        return Column(children: [
          SizedBox(
            height: 235,
            child: PageView.builder(
              controller: slideshowController,
              itemCount: slideItems.length,
              onPageChanged: (index) => setState(() => slideIndex = index),
              itemBuilder: (context, index) {
                final item = slideItems[index];
                return InkWell(
                  onTap: () => openArticle(item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(fit: StackFit.expand, children: [
                      if (item.image.startsWith('https://'))
                        Image.network(item.image, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                            const ColoredBox(color: brandDarkBlue))
                      else
                        const ColoredBox(color: brandDarkBlue),
                      const DecoratedBox(decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xE8000000)]))),
                      Positioned(left: 16, right: 16, bottom: 18,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(color: brandRed,
                                borderRadius: BorderRadius.circular(5)),
                              child: const Text('LATEST NEWS',
                                style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.bold, fontSize: 11))),
                            const SizedBox(height: 8),
                            Text(item.title, maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white,
                                fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(item.date, style: const TextStyle(
                              color: Colors.white70, fontSize: 11)),
                          ]),
                      ),
                      Positioned(left: 4, top: 85,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_left,
                            color: Colors.white, size: 32),
                          onPressed: () => slideshowController.animateToPage(
                            (slideIndex - 1 + slideItems.length) % slideItems.length,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut))),
                      Positioned(right: 4, top: 85,
                        child: IconButton(
                          icon: const Icon(Icons.chevron_right,
                            color: Colors.white, size: 32),
                          onPressed: () => slideshowController.animateToPage(
                            (slideIndex + 1) % slideItems.length,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut))),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 7),
          Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(slideItems.length, (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == slideIndex ? 17 : 7, height: 7,
              decoration: BoxDecoration(
                color: index == slideIndex ? brandBlue : Colors.blueGrey.shade200,
                borderRadius: BorderRadius.circular(10))))),
        ]);
      },
    );
  }

  Widget _quickAccessRow() {
    final shortcuts = <({String label, IconData icon, Color color, VoidCallback tap})>[
      (label: 'News', icon: Icons.newspaper, color: const Color(0xFFEA1429),
        tap: () => setState(() => tab = 3)),
      (label: 'Live TV', icon: Icons.live_tv, color: const Color(0xFF00A85A),
        tap: () => setState(() => tab = 1)),
      (label: 'FM Radio', icon: Icons.radio, color: const Color(0xFF8420E5),
        tap: () => setState(() => tab = 2)),
      (label: 'Videos', icon: Icons.play_circle, color: const Color(0xFFF77B08),
        tap: () => openNews('Videos', '/category/videos/')),
      (label: 'Sri Lanka', icon: Icons.public, color: const Color(0xFF096AF0),
        tap: () => openNews('Sri Lanka', '/srilanka')),
      (label: 'More', icon: Icons.grid_view, color: const Color(0xFFDB135E),
        tap: () => setState(() => tab = 4)),
    ];
    return SizedBox(height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shortcuts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = shortcuts[index];
          return Material(color: item.color,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(onTap: item.tap,
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(width: 91,
                child: Column(mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, color: Colors.white, size: 29),
                    const SizedBox(height: 6),
                    Text(item.label, style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold,
                      fontSize: 12)),
                  ])),
            ),
          );
        },
      ),
    );
  }

  Widget _breakingNewsBanner() {
    return FutureBuilder<List<NewsItem>>(
      future: newsFuture,
      builder: (context, snapshot) {
        final items =
            snapshot.data ?? <NewsItem>[];

        final NewsItem? latest =
            items.isNotEmpty ? items.first : null;

        final isLoading =
            snapshot.connectionState !=
            ConnectionState.done;

        return Material(
          color: brandRed,
          borderRadius:
              BorderRadius.circular(12),
          child: InkWell(
            borderRadius:
                BorderRadius.circular(12),
            onTap: latest == null
                ? refreshNews
                : () => openArticle(latest),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
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
                          fontWeight:
                              FontWeight.bold,
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
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  if (latest != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'முழுச் செய்தியைப் படிக்க அழுத்துங்கள் ›',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip:
                              'Share Breaking News',
                          onPressed: () {
                            shareNews(latest);
                          },
                          icon: const Icon(
                            Icons.share,
                            color: Colors.white,
                          ),
                        ),
                      ],
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
                icon: const Icon(
                  Icons.refresh,
                ),
              ),
            ],
          ),
          TextField(
            controller: searchController,
            onChanged: (value) => setState(() => searchQuery = value.trim()),
            decoration: InputDecoration(
              hintText: 'Search news / செய்திகளைத் தேடுங்கள்',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isEmpty ? null : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () { searchController.clear(); setState(() => searchQuery = ''); }),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true, fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          FilterChip(label: Text('Saved News (${savedIds.length})'),
            avatar: const Icon(Icons.bookmark, size: 18),
            selected: savedOnly,
            onSelected: (value) => setState(() => savedOnly = value)),
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
              child:
                  CircularProgressIndicator(
                color: brandRed,
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            color: Colors.white,
            child: Padding(
              padding:
                  const EdgeInsets.all(20),
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
                    textAlign:
                        TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: refreshNews,
                    icon: const Icon(
                      Icons.refresh,
                    ),
                    label: const Text(
                      'Retry',
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final allNews = snapshot.data ?? <NewsItem>[];
        final news = allNews.where((item) {
          if (savedOnly && !savedIds.contains(item.id)) return false;
          if (searchQuery.isNotEmpty &&
              !item.title.toLowerCase().contains(searchQuery.toLowerCase())) {
            return false;
          }
          return true;
        }).toList();

        if (news.isEmpty) {
          return const Card(
            child: Padding(
              padding:
                  EdgeInsets.all(20),
              child: Text(
                'தற்போது செய்திகள் இல்லை.',
                textAlign:
                    TextAlign.center,
              ),
            ),
          );
        }

        return Column(
          children:
              news.map(_newsCard).toList(),
        );
      },
    );
  }

  Widget _newsCard(NewsItem news) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openArticle(news),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            if (news.image.startsWith(
              'https://',
            ))
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
              padding:
                  const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    news.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
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
                      const SizedBox(
                        width: 5,
                      ),
                      Expanded(
                        child: Text(
                          news.date,
                          style:
                              const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: savedIds.contains(news.id) ? 'Remove saved news' : 'Save news',
                        onPressed: () => toggleSaved(news),
                        icon: Icon(savedIds.contains(news.id)
                          ? Icons.bookmark : Icons.bookmark_border,
                          color: brandBlue),
                      ),
                      IconButton(
                        tooltip: 'Share News',
                        onPressed: () {
                          shareNews(news);
                        },
                        icon: const Icon(
                          Icons.share,
                          color: brandRed,
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
      borderRadius:
          BorderRadius.circular(14),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 31,
              color: brandRed,
            ),
            const SizedBox(height: 9),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _more() {
    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        Image.asset(
          logoAsset,
          height: 105,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 12),
        const Center(
          child: Text(
            'உலகத் தமிழர்களின் ஊடகம்',
          ),
        ),
        const SizedBox(height: 20),
        Card(
          color: Colors.white,
          child: ListTile(
            leading: const Icon(
              Icons.radio,
              color: brandRed,
            ),
            title: const Text(
              'YARLSRI FM Radio',
            ),
            trailing: const Icon(
              Icons.chevron_right,
            ),
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
              title: Text(
                category.title,
              ),
              trailing: const Icon(
                Icons.chevron_right,
              ),
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
            title: const Text(
              'Visit Our Website',
            ),
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

// One shared player and a watchdog for interrupted live streams.
class YarlsriRadio {
  YarlsriRadio._() {
    _stateSubscription = player.playerStateStream.listen((state) {
      if (!_wantsPlayback) return;
      if (state.processingState == ProcessingState.ready && state.playing) {
        _bufferingSince = null;
        _retryCount = 0;
      } else if (state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering) {
        _bufferingSince ??= DateTime.now();
      } else if (state.processingState == ProcessingState.completed) {
        _scheduleReconnect();
      }
    });
    _eventSubscription = player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stack) {
        if (_wantsPlayback) _scheduleReconnect();
      },
    );
    _watchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_wantsPlayback || _busy || _retryTimer != null) return;
      final since = _bufferingSince;
      if (since != null &&
          DateTime.now().difference(since) > const Duration(seconds: 18)) {
        _scheduleReconnect();
      }
    });
  }

  static final YarlsriRadio instance = YarlsriRadio._();
  final AudioPlayer player = AudioPlayer();
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<PlaybackEvent>? _eventSubscription;
  Timer? _watchdog;
  Timer? _retryTimer;
  DateTime? _bufferingSince;
  bool _wantsPlayback = false;
  bool _busy = false;
  int _retryCount = 0;

  Future<void> start() async {
    _wantsPlayback = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_busy) return;
    _busy = true;
    try {
      if (player.audioSource == null) {
        _bufferingSince = DateTime.now();
        await _loadStream();
      }
      if (!_wantsPlayback) return;
      // Live playback may never finish; do not await the play future.
      unawaited(player.play().catchError((Object e) {
        if (_wantsPlayback) _scheduleReconnect();
      }));
    } catch (e) {
      if (_wantsPlayback) _scheduleReconnect();
    } finally {
      _busy = false;
    }
  }

  Future<void> _loadStream() async {
    await player.setAudioSource(AudioSource.uri(
      Uri.parse(fmStream),
      tag: const MediaItem(
        id: 'yarlsri-fm',
        title: 'YARLSRI FM Radio',
        artist: 'YARLSRI MEDIA',
      ),
    ));
  }

  void _scheduleReconnect() {
    if (!_wantsPlayback || _retryTimer != null) return;
    // Back off to avoid hammering the radio server during an outage.
    final seconds = _retryCount < 2 ? 3 : (_retryCount < 5 ? 8 : 20);
    _retryCount++;
    _retryTimer = Timer(Duration(seconds: seconds), () {
      _retryTimer = null;
      unawaited(_reconnect());
    });
  }

  Future<void> _reconnect() async {
    if (!_wantsPlayback || _busy) {
      if (_wantsPlayback && _busy) _scheduleReconnect();
      return;
    }
    _busy = true;
    try {
      _bufferingSince = DateTime.now();
      await player.stop();
      if (!_wantsPlayback) return;
      await _loadStream();
      if (!_wantsPlayback) return;
      unawaited(player.play().catchError((Object e) {
        if (_wantsPlayback) _scheduleReconnect();
      }));
    } catch (e) {
      if (_wantsPlayback) _scheduleReconnect();
    } finally {
      _busy = false;
    }
  }

  Future<void> toggle() async {
    if (_wantsPlayback) {
      _wantsPlayback = false;
      _retryTimer?.cancel();
      _retryTimer = null;
      _bufferingSince = null;
      await player.pause();
    } else {
      await start();
    }
  }

  bool get wantsPlayback => _wantsPlayback;
}

class FMRadioScreen extends StatefulWidget {
  const FMRadioScreen({super.key});

  @override
  State<FMRadioScreen> createState() => _FMRadioScreenState();
}

class _FMRadioScreenState extends State<FMRadioScreen> {
  final AudioPlayer player = YarlsriRadio.instance.player;
  StreamSubscription<PlayerState>? _stateSubscription;
  Timer? _animationTimer;
  bool connecting = false;
  bool playing = false;
  bool buffering = false;
  double volume = 0.8;
  double phase = 0;
  String? error;

  static const _rainbow = <Color>[
    Color(0xFF20EF65), Color(0xFFF9EF18), Color(0xFFFF7B16),
    Color(0xFFFF2757), Color(0xFF00DEEB), Color(0xFF2769FF),
    Color(0xFFCE2EFF),
  ];

  @override
  void initState() {
    super.initState();
    playing = YarlsriRadio.instance.wantsPlayback;
    volume = player.volume;
    buffering = player.processingState == ProcessingState.loading ||
        player.processingState == ProcessingState.buffering;
    _stateSubscription = player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        playing = YarlsriRadio.instance.wantsPlayback;
        buffering = state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });
    });
    // Decorative motion; just_audio does not expose live PCM/FFT levels.
    _animationTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      if (mounted && playing && !buffering) {
        setState(() => phase += 0.36);
      }
    });
  }

  Future<void> toggleRadio() async {
    if (connecting) return;
    setState(() { connecting = true; error = null; });
    try {
      await YarlsriRadio.instance.toggle();
      if (mounted) setState(() => playing = YarlsriRadio.instance.wantsPlayback);
    } catch (e) {
      if (mounted) setState(() => error = 'FM Radio இணைக்க முடியவில்லை: $e');
    } finally {
      if (mounted) setState(() => connecting = false);
    }
  }

  Future<void> changeVolume(double v) async {
    setState(() => volume = v);
    await player.setVolume(v);
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _animationTimer?.cancel();
    super.dispose();
  }

  Widget _bars({int count = 12, double height = 125}) {
    final active = playing && !buffering;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(count, (i) {
          final wave = math.sin(phase + i * 0.68).abs();
          final second = math.cos(phase * 0.57 + i * 1.19).abs();
          final level = active ? (0.20 + wave * 0.52 + second * 0.28) : 0.16;
          return Container(
            width: 7,
            height: height * level,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [_rainbow[i % _rainbow.length],
                  _rainbow[(i + 2) % _rainbow.length]],
              ),
              boxShadow: [BoxShadow(color: _rainbow[i % _rainbow.length]
                  .withValues(alpha: 0.35), blurRadius: 8)],
            ),
          );
        }),
      ),
    );
  }

  Widget _mixerChannel(int i) {
    final active = playing && !buffering;
    final level = active ? 0.18 + 0.72 *
        math.sin(phase * 0.6 + i * 1.1).abs() : 0.18;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF101D38),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFF3D5878)),
        ),
        child: Column(children: [
          Text('CH ${i + 1}', style: const TextStyle(
            color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(height: 78, child: Stack(alignment: Alignment.bottomCenter,
            children: [
              Container(width: 10, decoration: BoxDecoration(
                color: Colors.white12, borderRadius: BorderRadius.circular(5))),
              Container(width: 10, height: 78 * level,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Color(0xFF00D9E8), Color(0xFF59FF53),
                      Color(0xFFFFD719), Color(0xFFFF3454)]))),
              Positioned(bottom: 78 * level - 3,
                child: Container(width: 28, height: 7,
                  decoration: BoxDecoration(color: const Color(0xFFB9D9ED),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white70)))),
            ])),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF061433),
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.15),
              radius: 1.15,
              colors: [
                Color(0xFF173D8D),
                Color(0xFF141C55),
                Color(0xFF160D34),
                Color(0xFF060F2B),
              ],
              stops: [0.0, 0.40, 0.75, 1.0],
            ),
          ),
          child: Column(children: [
            const Text('YARLSRI FM RADIO', textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 24,
                fontWeight: FontWeight.w900, letterSpacing: 0.7)),
            const SizedBox(height: 5),
            const Text('உலகத் தமிழர்களின் வானொலி',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 17),
            SizedBox(height: 232, child: Stack(alignment: Alignment.center,
              children: [
                Positioned(left: 0, right: 0, bottom: 18,
                  child: Row(children: [
                    Expanded(child: _bars(count: 9, height: 130)),
                    const SizedBox(width: 190),
                    Expanded(child: _bars(count: 9, height: 130)),
                  ])),
                // Neon DJ mixer halo: original FM image remains unchanged.
                Container(
                  width: 226, height: 226,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF08D9FF), width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0xAA008BFF), blurRadius: 27, spreadRadius: 2),
                      BoxShadow(color: Color(0x99FF18B4), blurRadius: 37, spreadRadius: 1),
                    ],
                  ),
                ),
                Container(
                  width: 214, height: 214,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(colors: [
                      Color(0xFFFF2254), Color(0xFFFF22BB),
                      Color(0xFF05DAFF), Color(0xFF245CFF),
                      Color(0xFFFF2254),
                    ]),
                    boxShadow: const [
                      BoxShadow(color: Color(0x99F81B50), blurRadius: 20),
                    ],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF30475D),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        fmLogoAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.radio, size: 70, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ])),
            const SizedBox(height: 16),
            Container(padding: const EdgeInsets.symmetric(
              horizontal: 23, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFFED153A),
                borderRadius: BorderRadius.circular(28)),
              child: const Text('● LIVE RADIO', style: TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            Text(error != null ? 'CONNECTION ERROR'
                : buffering ? 'Connecting to live stream...'
                : playing ? 'Now Playing • LIVE' : 'Tap Play to listen',
              style: const TextStyle(color: Colors.white,
                fontSize: 16, fontWeight: FontWeight.w600)),
            if (error != null) Padding(
              padding: const EdgeInsets.all(8),
              child: Text(error!, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFFA6B1)))),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton.filledTonal(
                tooltip: 'Mute / Unmute',
                onPressed: () => changeVolume(volume == 0 ? 0.8 : 0),
                icon: Icon(volume == 0 ? Icons.volume_off : Icons.volume_up)),
              const SizedBox(width: 24),
              SizedBox(width: 82, height: 82,
                child: FilledButton(
                  onPressed: connecting ? null : toggleRadio,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF1123C),
                    shape: const CircleBorder(), padding: EdgeInsets.zero),
                  child: connecting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white, size: 48))),
              const SizedBox(width: 24),
              const Icon(Icons.graphic_eq, color: Colors.white70, size: 34),
            ]),
          ]),
        ),
        Padding(padding: const EdgeInsets.fromLTRB(12, 14, 12, 22),
          child: Column(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(color: const Color(0xFF14274F),
                borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Icon(Icons.volume_up, color: Colors.white),
                Expanded(child: Slider(value: volume, min: 0, max: 1,
                  activeColor: const Color(0xFFF21946),
                  onChanged: changeVolume)),
                Text('${(volume * 100).round()}%',
                  style: const TextStyle(color: Colors.white)),
              ])),
            const SizedBox(height: 15),
            const Text('DJ LIGHT MIXER', style: TextStyle(
              color: Colors.white, fontSize: 16,
              fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(height: 3),
            const Text('Animated lights • Volume control above',
              style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 12),
            Row(children: List.generate(5, _mixerChannel)),
            const SizedBox(height: 15),
            const Text('FM நேரலையில் பாடலை Skip செய்ய முடியாது.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
      ]),
    );
  }
}

class LiveTVScreen extends StatefulWidget {
  const LiveTVScreen({super.key});

  @override
  State<LiveTVScreen> createState() =>
      _LiveTVScreenState();
}

class _LiveTVScreenState
    extends State<LiveTVScreen> {
  late final VideoPlayerController
      controller;

  bool ready = false;
  String? error;

  @override
  void initState() {
    super.initState();

    controller =
        VideoPlayerController.networkUrl(
      Uri.parse(liveStream),
    );

    _start();
  }

  Future<void> _start() async {
    try {
      await controller.initialize();

      if (!mounted) return;

      setState(() {
        ready = true;
      });

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
      padding:
          const EdgeInsets.all(16),
      children: [
        const Text(
          'YARLSRI TV',
          textAlign:
              TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight:
                FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            '● LIVE BROADCAST',
            style: TextStyle(
              color: brandRed,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          color: Colors.black,
          child: AspectRatio(
            aspectRatio:
                ready &&
                        controller.value
                                .aspectRatio >
                            0
                    ? controller.value
                        .aspectRatio
                    : 16 / 9,
            child: error != null
                ? Center(
                    child: Padding(
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),
                      child: Text(
                        error!,
                        textAlign:
                            TextAlign.center,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                        ),
                      ),
                    ),
                  )
                : ready
                    ? VideoPlayer(
                        controller,
                      )
                    : const Center(
                        child:
                            CircularProgressIndicator(
                          color:
                              Colors.white,
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
                  if (controller
                      .value.isPlaying) {
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
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Retry',
              ),
            ),
          ),
        const SizedBox(height: 18),
        const Text(
          'YARLSRI TV நேரடி ஒளிபரப்பு',
          textAlign:
              TextAlign.center,
          style: TextStyle(
            fontWeight:
                FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'ஒளிபரப்பைப் பார்க்க இணைய இணைப்பு தேவை.',
          textAlign:
              TextAlign.center,
        ),
      ],
    );
  }
}

class WebsiteScreen
    extends StatefulWidget {
  final String title;
  final String url;
  final bool embedded;
  final String? shareTitle;

  const WebsiteScreen({
    super.key,
    required this.title,
    required this.url,
    this.embedded = false,
    this.shareTitle,
  });

  @override
  State<WebsiteScreen> createState() =>
      _WebsiteScreenState();
}

class _WebsiteScreenState
    extends State<WebsiteScreen> {
  late final WebViewController
      controller;

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
              setState(() {
                loading = true;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                loading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.url),
      );
  }

  Future<void> shareArticle() async {
    final text =
        '${widget.shareTitle ?? widget.title}\n\n'
        '${widget.url}\n\n'
        'YARLSRI MEDIA';

    try {
      await Share.share(
        text,
        subject:
            widget.shareTitle ??
                widget.title,
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'செய்தியைப் பகிர முடியவில்லை.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        WebViewWidget(
          controller: controller,
        ),
        if (loading)
          const Center(
            child:
                CircularProgressIndicator(
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
        title: Text(
          widget.title,
        ),
        actions: [
          if (widget.shareTitle != null)
            IconButton(
              tooltip: 'Share News',
              icon: const Icon(
                Icons.share,
              ),
              onPressed:
                  shareArticle,
            ),
          IconButton(
            icon: const Icon(
              Icons.refresh,
            ),
            onPressed: () {
              controller.reload();
            },
          ),
        ],
      ),
      body: content,
    );
  }
}
