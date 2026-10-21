import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';

const brandRed = Color(0xFFFF172D);
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
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.yarlsrimedia.yarlsri_media.radio',
    androidNotificationChannelName: 'YARLSRI FM Radio',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: false,
  );
  runApp(const YarlsriMediaApp());
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
          backgroundColor: Color(0xFF212121),
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
  String selectedLanguage = 'en';

  // Start in English on every fresh app launch.
  Future<void> _loadLanguage() async {
    if (mounted) setState(() => selectedLanguage = 'en');
  }

  Future<void> _changeLanguage(String value) async {
    setState(() => selectedLanguage = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('yarlsri_language', value);
  }

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
      'Tamil Nadu': {'ta':'தமிழ்நாடு','en':'Tamil Nadu','si':'තමිල්නාඩු','hi':'तमिलनाडु','fr':'Tamil Nadu','es':'Tamil Nadu','it':'Tamil Nadu','de':'Tamil Nadu','ar':'تاميل نادو','ml':'തമിഴ്നാട്'},
      'FM Radio': {'ta':'FM வானொலி','en':'FM Radio','si':'FM ගුවන්විදුලිය','hi':'FM रेडियो','fr':'Radio FM','es':'Radio FM','it':'Radio FM','de':'FM-Radio','ar':'راديو FM','ml':'FM റേഡിയോ'},
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
        color: const Color(0xFF111111),
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
            onSelected: _changeLanguage,
            itemBuilder: (_) => languageNames.entries.map((entry) =>
              PopupMenuItem<String>(value: entry.key,
                child: Row(children: [
                  Expanded(child: Text(entry.value)),
                  if (entry.key == selectedLanguage)
                    const Icon(Icons.check, color: Colors.green),
                ]),
              )).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(languageNames[selectedLanguage]!.split(' ').first,
                  style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 2),
                Text(selectedLanguage.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.keyboard_arrow_down, size: 15),
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
    final tvFullscreen = tab == 1 &&
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Scaffold(
      appBar: tvFullscreen ? null : AppBar(
        backgroundColor: brandBlue,
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
          tab == 1 ? const LiveTVScreen() : const SizedBox.shrink(),
          const FMRadioScreen(),
          _newsPage(),
          _more(),
        ],
      ),
      bottomNavigationBar: tvFullscreen ? null : NavigationBar(
        height: 66,
        backgroundColor: brandRed,
        indicatorColor: const Color(0xFFDA1027),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(color: Colors.white, fontSize: 10,
            fontWeight: FontWeight.w600, height: 1.15)),
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
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined, color: Colors.white),
            selectedIcon: Icon(Icons.live_tv, color: Colors.white),
            label: tr('Live TV')),
          NavigationDestination(
            icon: Icon(Icons.radio_outlined, color: Colors.white),
            selectedIcon: Icon(Icons.radio, color: Colors.white),
            label: tr('FM Radio')),
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
        const SizedBox(height: 12),
        ...const <({String title, IconData icon, String key})>[
          (title: 'Privacy Policy', icon: Icons.privacy_tip_outlined, key: 'privacy'),
          (title: 'About Us', icon: Icons.info_outline, key: 'about'),
          (title: 'Contact Us', icon: Icons.contact_mail_outlined, key: 'contact'),
          (title: 'Terms & Conditions', icon: Icons.description_outlined, key: 'terms'),
        ].map((page) => Card(
          color: Colors.white,
          child: ListTile(
            leading: Icon(page.icon, color: brandRed),
            title: Text(page.title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => YarlsriInfoPage(pageKey: page.key, title: page.title),
              ),
            ),
          ),
        )),
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


// Informational pages. Review privacy claims and contact details before publishing.
class YarlsriInfoPage extends StatelessWidget {
  final String pageKey;
  final String title;
  const YarlsriInfoPage({super.key, required this.pageKey, required this.title});

  static const Map<String, String> _body = {
    'privacy': '''YARLSRI MEDIA — Privacy Policy
Last updated: 21 October 2026

YARLSRI MEDIA provides live television, FM radio, and news content. This notice explains the main features that may involve information about your use of the app.

News and streaming: When you load news, television, radio or website content, the relevant servers and service providers may receive technical information such as your IP address and request details to deliver that content.

On-device preferences: The app uses local storage for language selection and saved news identifiers. These preferences are used to support app features on your device.

Sharing: If you choose to share an article, the Android sharing interface sends the selected article information to the app or recipient you choose.

External content: News pages and media streams may be delivered by third-party infrastructure. Their practices may differ from ours.

Children: The app is intended for a general audience. Parents and guardians should supervise children's use of news and media services as appropriate.

Your choices: You can stop using the app or clear its local data through your device settings. For privacy questions, contact us through our official website: https://yarlsrimedia.com

IMPORTANT BEFORE PUBLICATION: This policy must be checked against the app's actual analytics, advertising, hosting, retention and data-sharing practices. Publish an accurate, publicly accessible copy on the official website and use its URL in Google Play Console.''',
    'about': '''About YARLSRI MEDIA

YARLSRI MEDIA is a media app bringing together live television, YARLSRI FM radio, news, and video links in one place.

Our goal is to make news and media content accessible to audiences across locations and languages.

Features include:
• Live TV streaming
• FM radio playback
• News articles and categories
• Article sharing and saved news
• Language selection

Official website: https://yarlsrimedia.com''',
    'contact': '''Contact YARLSRI MEDIA

For feedback, news corrections, technical support, privacy requests, or copyright enquiries, please contact YARLSRI MEDIA through the official website:

https://yarlsrimedia.com

Please include the subject of your request and relevant article or feature details. Do not include passwords or sensitive identification documents in general feedback.

Before publishing on Google Play, add a monitored support email address and a direct contact page or form if available.''',
    'terms': '''YARLSRI MEDIA — Terms & Conditions
Last updated: 21 October 2026

By using this app, you agree to use it lawfully and respectfully.

Content: The app provides access to news, television, radio and linked web content. Availability and schedules may change without notice.

Intellectual property: Articles, logos, photographs, video and audio remain subject to the rights of their respective owners. Do not reproduce or redistribute protected content without permission.

Links and services: Some content may be provided through external websites or streaming services. Those services may have separate terms.

Availability: We aim to provide a reliable experience, but uninterrupted access is not guaranteed. Network and provider issues may affect playback.

Accuracy: News information can change as events develop. Contact us through the official website to request a correction.

Contact: https://yarlsrimedia.com

These terms should be reviewed for your actual business and content rights before publication.''',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: brandBlue,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(_body[pageKey] ?? '', style: const TextStyle(fontSize: 15, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

// Shared radio player: Android media notification and background audio.
class YarlsriRadio {
  YarlsriRadio._() {
    player.playerStateStream.listen((state) {
      playing.value = state.playing;
      buffering.value = _wantsPlayback &&
          (state.processingState == ProcessingState.loading ||
           state.processingState == ProcessingState.buffering);
      if (_wantsPlayback && state.processingState == ProcessingState.completed) {
        _reconnect();
      }
    });
    player.playbackEventStream.listen((_) {}, onError: (Object e, StackTrace st) {
      if (_wantsPlayback) {
        error.value = 'FM இணைப்பில் சிக்கல். மீண்டும் Play அழுத்துங்கள்.';
        buffering.value = false;
      }
    });
  }

  static final YarlsriRadio instance = YarlsriRadio._();
  final AudioPlayer player = AudioPlayer();
  final ValueNotifier<bool> playing = ValueNotifier<bool>(false);
  final ValueNotifier<bool> buffering = ValueNotifier<bool>(false);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);
  bool _wantsPlayback = false;
  bool _busy = false;
  int volume = 80;

  Future<void> _load() async {
    await player.setAudioSource(AudioSource.uri(
      Uri.parse(fmStream),
      tag: const MediaItem(
        id: 'yarlsri-fm-live',
        title: 'YARLSRI FM Radio',
        artist: 'YARLSRI MEDIA',
        isLive: true,
      ),
    ));
    await player.setVolume(volume / 100);
  }

  Future<void> _reconnect() async {
    if (!_wantsPlayback || _busy) return;
    _busy = true;
    try {
      await _load();
      if (_wantsPlayback) {
        unawaited(player.play().catchError((Object e) {
          error.value = 'FM இணைக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';
        }));
      }
    } catch (_) {
      error.value = 'FM இணைக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';
    } finally {
      _busy = false;
    }
  }

  Future<void> toggle() async {
    if (_busy) return;
    _busy = true;
    try {
      error.value = null;
      if (_wantsPlayback) {
        _wantsPlayback = false;
        buffering.value = false;
        await player.pause();
      } else {
        _wantsPlayback = true;
        buffering.value = true;
        if (player.audioSource == null) await _load();
        if (_wantsPlayback) {
          unawaited(player.play().catchError((Object e) {
            error.value = 'FM இணைக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';
            buffering.value = false;
          }));
        }
      }
    } catch (e) {
      _wantsPlayback = false;
      playing.value = false;
      buffering.value = false;
      error.value = 'FM Radio இணைக்க முடியவில்லை: $e';
    } finally {
      _busy = false;
    }
  }

  Future<void> setVolume(double v) async {
    volume = (v * 100).round().clamp(0, 100);
    await player.setVolume(volume / 100);
  }

  bool get wantsPlayback => _wantsPlayback;
}

class FMRadioScreen extends StatefulWidget {
  const FMRadioScreen({super.key});

  @override
  State<FMRadioScreen> createState() => _FMRadioScreenState();
}

class _FMRadioScreenState extends State<FMRadioScreen> {
  final YarlsriRadio radio = YarlsriRadio.instance;
  Timer? _animationTimer;
  bool connecting = false;
  bool playing = false;
  bool buffering = false;
  double volume = 0.8;
  double phase = 0;
  String? error;

  void _update() {
    if (!mounted) return;
    setState(() {
      playing = radio.playing.value;
      buffering = radio.buffering.value;
      error = radio.error.value;
    });
  }

  static const _rainbow = <Color>[
    Color(0xFF20EF65), Color(0xFFF9EF18), Color(0xFFFF7B16),
    Color(0xFFFF2757), Color(0xFF00DEEB), Color(0xFF2769FF),
    Color(0xFFCE2EFF),
  ];

  @override
  void initState() {
    super.initState();
    playing = radio.wantsPlayback;
    buffering = radio.buffering.value;
    volume = radio.volume / 100;
    error = radio.error.value;
    radio.playing.addListener(_update);
    radio.buffering.addListener(_update);
    radio.error.addListener(_update);
    _animationTimer = Timer.periodic(const Duration(milliseconds: 140), (_) {
      if (mounted && playing && !buffering) {
        setState(() => phase += 0.36);
      }
    });
  }

  Future<void> toggleRadio() async {
    if (connecting) return;
    setState(() => connecting = true);
    await radio.toggle();
    if (mounted) setState(() => connecting = false);
  }

  Future<void> changeVolume(double v) async {
    setState(() => volume = v);
    await radio.setVolume(v);
  }

  @override
  void dispose() {
    radio.playing.removeListener(_update);
    radio.buffering.removeListener(_update);
    radio.error.removeListener(_update);
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
  State<LiveTVScreen> createState() => _LiveTVScreenState();
}

class _LiveTVScreenState extends State<LiveTVScreen> {
  late final VideoPlayerController controller;
  bool ready = false;
  bool loading = false;
  String? error;

  static const gold = Color(0xFFFF2449);
  static const darkGold = Color(0xFF7C0920);

  @override
  void initState() {
    super.initState();
    controller = VideoPlayerController.networkUrl(Uri.parse(liveStream));
    controller.addListener(_refreshPlayer);
    // No autoplay: stream starts only after the user taps Play.
  }

  void _refreshPlayer() {
    if (mounted && ready) setState(() {});
  }

  Future<void> _togglePlayback() async {
    if (loading) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }
    if (ready) {
      await controller.play();
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() { ready = true; loading = false; });
      await controller.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error = 'Live TV இணைக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.';
        });
      }
    }
  }

  @override
  void dispose() {
    controller.removeListener(_refreshPlayer);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = ready && controller.value.isPlaying;
    final fullscreen = MediaQuery.orientationOf(context) == Orientation.landscape;
    if (fullscreen) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: ready && controller.value.aspectRatio > 0
                ? controller.value.aspectRatio : 16 / 9,
            child: ready
                ? VideoPlayer(controller)
                : Center(
                    child: loading
                        ? const CircularProgressIndicator(color: gold)
                        : TextButton.icon(
                            onPressed: _togglePlayback,
                            icon: const Icon(Icons.play_circle, color: Colors.white),
                            label: const Text('PLAY LIVE',
                                style: TextStyle(color: Colors.white)),
                          ),
                  ),
          ),
        ),
      );
    }
    return ColoredBox(
      color: const Color(0xFF10080C),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_fill_rounded,
                color: Color(0xFFFF2449), size: 38),
              SizedBox(width: 10),
              Text('YARLSRI', style: TextStyle(
                color: Colors.white, fontSize: 28,
                fontWeight: FontWeight.w900, letterSpacing: 1)),
              SizedBox(width: 6),
              Text('TV', style: TextStyle(
                color: Color(0xFFFF2449), fontSize: 29,
                fontWeight: FontWeight.w900, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 5),
          const Text('● LIVE TELEVISION',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70,
              fontSize: 11, letterSpacing: 2)),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [darkGold, gold, Color(0xFFFF768C), gold, darkGold]),
              boxShadow: const [BoxShadow(
                color: Color(0x77FF2449), blurRadius: 20, spreadRadius: 2)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: ColoredBox(
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: ready && controller.value.aspectRatio > 0
                      ? controller.value.aspectRatio : 16 / 9,
                  child: ready
                      ? VideoPlayer(controller)
                      : Center(child: loading
                          ? const CircularProgressIndicator(color: gold)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.live_tv, color: gold, size: 54),
                                SizedBox(height: 12),
                                Text('PLAY அழுத்தி நேரலையைப் பார்க்கவும்',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70)),
                              ],
                            )),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF350A16),
              border: Border.all(color: const Color(0xFFFF2449)),
              borderRadius: BorderRadius.circular(30)),
            child: const Text('● LIVE  •  YARLSRI TV',
              style: TextStyle(color: Color(0xFFFF7B91),
                fontWeight: FontWeight.bold, letterSpacing: 1)),
          )),
          const SizedBox(height: 22),
          Center(child: SizedBox(
            width: 210,
            height: 56,
            child: FilledButton.icon(
              onPressed: loading ? null : _togglePlayback,
              style: FilledButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30))),
              icon: Icon(playing ? Icons.pause_circle : Icons.play_circle,
                size: 27),
              label: Text(loading ? 'CONNECTING...' : playing ? 'PAUSE' : 'PLAY LIVE',
                style: const TextStyle(fontWeight: FontWeight.w900,
                  letterSpacing: 1)),
            ),
          )),
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(error!, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent)),
          ],
          const SizedBox(height: 24),
          const Divider(color: darkGold),
          const SizedBox(height: 10),
          const Text('உலகத் தமிழர்களின் தொலைக்காட்சி',
            textAlign: TextAlign.center,
            style: TextStyle(color: gold, fontWeight: FontWeight.bold,
              fontSize: 16)),
          const SizedBox(height: 8),
          const Text('நேரலையைப் பார்க்க இணைய இணைப்பு தேவை.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
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
