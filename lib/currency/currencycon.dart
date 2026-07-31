import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tremsolapp/homescreen.dart';



class CountryInfo {
  final String currencyCode;
  final String countryName;
  final String flagUrl;

  CountryInfo({
    required this.currencyCode,
    required this.countryName,
    required this.flagUrl,
  });
}

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  _CurrencyConverterScreenState createState() =>
      _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> {
  String? baseCurrency; // from Firestore settings/doc4.baseCurrency
  String? selectedCurrency; // what user chooses
  double? conversionRate;

  final TextEditingController searchController = TextEditingController();

  List<String> availableCurrencies = [];
  List<String> filteredCurrencies = [];
  String? apiKey;

  bool isLoading = true;
  List<CountryInfo> countryCurrencyList = [];

  // Tiny map for common currencies → ISO 3166-1 alpha-2 (for a reliable flag CDN)
  static const Map<String, String> _currencyToCca2Hint = {
    'USD': 'us',
    'EUR': 'eu',
    'GBP': 'gb',
    'GHS': 'gh',
    'NGN': 'ng',
    'KES': 'ke',
    'ZAR': 'za',
    'CNY': 'cn',
    'JPY': 'jp',
    'INR': 'in',
    'CAD': 'ca',
    'AUD': 'au',
  };

  String _flagCdn(String cca2) =>
      'https://flagcdn.com/w40/${cca2.toLowerCase()}.png';

  /// Normalize / override some currencies to nicer display
  CountryInfo _normalizeCurrencyInfo(CountryInfo info) {
    if (info.currencyCode == 'USD') {
      // Always show USD as "United States (USD)" with US flag
      return CountryInfo(
        currencyCode: 'USD',
        countryName: 'United States',
        flagUrl: _flagCdn('us'),
      );
    }
    return info;
  }

  @override
  void initState() {
    super.initState();
    initData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> initData() async {
    if (mounted) setState(() => isLoading = true);

    await fetchApiKey();
    await fetchBaseCurrency(); // also loads availableCurrencies via fetchAvailableCurrencies()

    // Use cache immediately if present
    final cachedList = await loadCountryCurrencyFromCache();
    if (cachedList != null && cachedList.isNotEmpty && mounted) {
      setState(() => countryCurrencyList = cachedList);
    }

    // Try network (multi-source) for flags/currency-country mapping
    final freshList = await fetchCountryCurrencyFlags();
    if (freshList.isNotEmpty && mounted) {
      setState(() => countryCurrencyList = freshList);
      await cacheCountryCurrencyList(freshList);
    }

    // Ensure we at least show something in the picker
    if (countryCurrencyList.isEmpty && availableCurrencies.isNotEmpty) {
      countryCurrencyList = availableCurrencies
          .map(
            (c) => CountryInfo(
              currencyCode: c,
              countryName: c,
              flagUrl: '',
            ),
          )
          .toList();
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> fetchApiKey() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('doc6')
          .get();
      if (doc.exists && mounted) {
        setState(() {
          apiKey = doc['exchangerate_api_key'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching API Key: $e");
    }
  }

  /// Fetch baseCurrency from Firestore and cache it locally so it becomes the
  /// default currency when the user hasn't chosen anything.
  Future<void> fetchBaseCurrency() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('doc4')
          .get();

      if (doc.exists) {
        final value = doc['baseCurrency'] as String;
        if (mounted) {
          setState(() {
            baseCurrency = value;
          });
        }

        // Cache baseCurrency so other screens (like loadCurrencyData) can use it
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('baseCurrency', value);
      }

      await fetchAvailableCurrencies();
    } catch (e) {
      debugPrint("Error fetching base currency: $e");
    }
  }

  Future<void> fetchAvailableCurrencies() async {
    if (baseCurrency == null || apiKey == null) return;

    final prefs = await SharedPreferences.getInstance();

    // Use cache first if available
    final cachedData = prefs.getString('cachedRates_$baseCurrency');
    if (cachedData != null) {
      try {
        final data = json.decode(cachedData);
        final rates = data['conversion_rates'];
        if (rates is Map && mounted) {
          setState(() {
            availableCurrencies =
                rates.keys.map((e) => e.toString()).toList();
            filteredCurrencies = List<String>.from(availableCurrencies);
          });

          debugPrint(
            "Has USD in availableCurrencies (cache): "
            "${availableCurrencies.contains('USD')}",
          );
        }
      } catch (e) {
        debugPrint("Error decoding cached rates: $e");
      }
    }

    // Refresh from network (with timeout + payload guard)
    try {
      final uri = Uri.parse(
        "https://v6.exchangerate-api.com/v6/$apiKey/latest/$baseCurrency",
      );
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Flutter'
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map &&
            data['result'] == 'success' &&
            data['conversion_rates'] is Map) {
          await prefs.setString(
              'cachedRates_$baseCurrency', response.body);
          if (mounted) {
            setState(() {
              availableCurrencies =
                  (data['conversion_rates'] as Map<String, dynamic>)
                      .keys
                      .map((e) => e.toString())
                      .toList();
              filteredCurrencies = List<String>.from(availableCurrencies);
            });

            debugPrint(
              "Has USD in availableCurrencies (network): "
              "${availableCurrencies.contains('USD')}",
            );
          }
        } else {
          debugPrint(
              "ExchangeRate latest payload not success: ${response.body}");
        }
      } else {
        debugPrint(
            "ExchangeRate latest failed: ${response.statusCode} ${response.body.isNotEmpty ? response.body.substring(0, math.min(200, response.body.length)) : ''}");
      }
    } on TimeoutException {
      debugPrint("ExchangeRate latest timeout");
    } catch (e) {
      debugPrint("Error fetching currencies: $e");
    }
  }

  Future<double?> fetchConversionRate(String? base, String target) async {
    if (base == null || apiKey == null) return null;

    final prefs = await SharedPreferences.getInstance();
    // Try cache
    final cachedRates = prefs.getString('cachedRates_$base');
    if (cachedRates != null) {
      try {
        final data = json.decode(cachedRates);
        final v = (data['conversion_rates']?[target]);
        if (v is num) return v.toDouble();
      } catch (e) {
        debugPrint("Error decoding cached conversion: $e");
      }
    }

    // Network with timeout + guard
    try {
      final uri = Uri.parse(
        "https://v6.exchangerate-api.com/v6/$apiKey/latest/$base",
      );
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Flutter'
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map &&
            data['result'] == 'success' &&
            data['conversion_rates'] is Map) {
          await prefs.setString('cachedRates_$base', response.body);
          final v = (data['conversion_rates'][target]);
          if (v is num) return v.toDouble();
        } else {
          debugPrint(
              "ExchangeRate payload not success: ${response.body}");
        }
      } else {
        debugPrint(
            "ExchangeRate latest failed: ${response.statusCode} ${response.body.isNotEmpty ? response.body.substring(0, math.min(200, response.body.length)) : ''}");
      }
    } on TimeoutException {
      debugPrint("ExchangeRate latest timeout");
    } catch (e) {
      debugPrint("Error fetching conversion rate: $e");
    }
    return null;
  }

  /// -------- Country/Currency + Flags (resilient, multi-source) --------

  Future<List<CountryInfo>> _fromRestCountriesV31() async {
    final uri = Uri.parse(
      'https://restcountries.com/v3.1/all?fields=name,cca2,currencies,flags',
    );
    try {
      final res = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Flutter'
            },
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        debugPrint(
            "restcountries v3.1 failed: ${res.statusCode} ${res.body.isNotEmpty ? res.body.substring(0, math.min(200, res.body.length)) : ''}");
        return [];
      }

      final List data = json.decode(res.body);
      final List<CountryInfo> list = [];
      for (final c in data) {
        final name = c['name'];
        final currencies = c['currencies'];
        final flags = c['flags'];
        final cca2 = (c['cca2'] ?? '') as String;

        if (name is Map && currencies is Map && flags != null) {
          final countryName = (name['common'] ?? '') as String;
          final flagUrl = (flags['png'] ??
                  flags['svg'] ??
                  (cca2.isNotEmpty ? _flagCdn(cca2) : '')) as String;
          currencies.forEach((code, _) {
            final info = _normalizeCurrencyInfo(
              CountryInfo(
                currencyCode: code.toString(),
                countryName: countryName,
                flagUrl: flagUrl,
              ),
            );
            list.add(info);
          });
        }
      }
      final seen = <String>{};
      return list.where((e) => seen.add(e.currencyCode)).toList();
    } on TimeoutException {
      debugPrint("restcountries v3.1 timeout");
      return [];
    } catch (e) {
      debugPrint("restcountries v3.1 error: $e");
      return [];
    }
  }

  Future<List<CountryInfo>> _fromRestCountriesV2() async {
    final uri = Uri.parse(
      'https://restcountries.com/v2/all?fields=name,alpha2Code,currencies,flags',
    );
    try {
      final res = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Flutter'
            },
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        debugPrint(
            "restcountries v2 failed: ${res.statusCode} ${res.body.isNotEmpty ? res.body.substring(0, math.min(200, res.body.length)) : ''}");
        return [];
      }

      final List data = json.decode(res.body);
      final List<CountryInfo> list = [];
      for (final c in data) {
        final countryName = (c['name'] ?? '') as String;
        final alpha2 = (c['alpha2Code'] ?? '') as String;
        final flags = c['flags'];
        final flagUrl = (flags is Map
                ? (flags['png'] ?? flags['svg'])
                : '') as String? ??
            (alpha2.isNotEmpty ? _flagCdn(alpha2) : '');

        final currencies = c['currencies'];
        if (currencies is List) {
          for (final cur in currencies) {
            final code = (cur['code'] ?? '').toString();
            if (code.isEmpty) continue;
            final info = _normalizeCurrencyInfo(
              CountryInfo(
                currencyCode: code,
                countryName: countryName,
                flagUrl: flagUrl,
              ),
            );
            list.add(info);
          }
        }
      }
      final seen = <String>{};
      return list.where((e) => seen.add(e.currencyCode)).toList();
    } on TimeoutException {
      debugPrint("restcountries v2 timeout");
      return [];
    } catch (e) {
      debugPrint("restcountries v2 error: $e");
      return [];
    }
  }

  Future<List<CountryInfo>> _fromExchangeRateCodes() async {
    if (apiKey == null) return [];
    final uri =
        Uri.parse('https://v6.exchangerate-api.com/v6/$apiKey/codes');
    try {
      final res = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'Flutter'
            },
          )
          .timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        debugPrint(
            "exchangerate codes failed: ${res.statusCode} ${res.body.isNotEmpty ? res.body.substring(0, math.min(200, res.body.length)) : ''}");
        return [];
      }

      final data = json.decode(res.body);
      final List codes = (data['supported_codes'] ?? []) as List;
      final List<CountryInfo> list = [];
      for (final pair in codes) {
        if (pair is List && pair.length >= 2) {
          final code = pair[0].toString();
          final currencyName =
              pair[1].toString(); // use currency name as display fallback
          final cca2 = _currencyToCca2Hint[code];
          final flagUrl = (cca2 != null) ? _flagCdn(cca2) : '';
          final info = _normalizeCurrencyInfo(
            CountryInfo(
              currencyCode: code,
              countryName: currencyName,
              flagUrl: flagUrl,
            ),
          );
          list.add(info);
        }
      }
      return list;
    } on TimeoutException {
      debugPrint("exchangerate codes timeout");
      return [];
    } catch (e) {
      debugPrint("exchangerate codes error: $e");
      return [];
    }
  }

  /// Multi-source fetcher with fallbacks. Never throws.
  Future<List<CountryInfo>> fetchCountryCurrencyFlags() async {
    final v31 = await _fromRestCountriesV31();
    if (v31.isNotEmpty) return v31;

    final v2 = await _fromRestCountriesV2();
    if (v2.isNotEmpty) return v2;

    final codes = await _fromExchangeRateCodes();
    if (codes.isNotEmpty) return codes;

    return [];
  }

  Future<void> cacheCountryCurrencyList(List<CountryInfo> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(
      list
          .map(
            (e) => {
              'currencyCode': e.currencyCode,
              'countryName': e.countryName,
              'flagUrl': e.flagUrl,
            },
          )
          .toList(),
    );
    await prefs.setString('countryCurrencyList', jsonString);
  }

  Future<List<CountryInfo>?> loadCountryCurrencyFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('countryCurrencyList');
    if (jsonString == null) return null;

    try {
      final List decoded = jsonDecode(jsonString);
      return decoded
          .map(
            (e) => CountryInfo(
              currencyCode: e['currencyCode'],
              countryName: e['countryName'],
              flagUrl: e['flagUrl'],
            ),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  void filterCurrencies(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      filteredCurrencies = countryCurrencyList
          .where(
            (country) =>
                country.currencyCode.toLowerCase().contains(lowerQuery) ||
                country.countryName.toLowerCase().contains(lowerQuery),
          )
          .map((country) => country.currencyCode)
          .toSet()
          .toList();
    });
  }

  Future<void> handleRefresh() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    await fetchAvailableCurrencies();
    final list = await fetchCountryCurrencyFlags();

    if (!mounted) return;
    if (list.isNotEmpty) {
      setState(() => countryCurrencyList = list);
      await cacheCountryCurrencyList(list);
    } else {
      // keep existing list; inform user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn’t refresh country data. Using cached data.",
          ),
        ),
      );
    }

    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _selectAndProceed(String currency) async {
    setState(() {
      selectedCurrency = currency;
    });

    final rate = await fetchConversionRate(baseCurrency, currency);
    if (rate != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedCurrency', currency);
      await prefs.setDouble('conversionRate', rate);
      await prefs.setBool('isFirstAccess', false);

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch rate for $currency")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultCurrencyLabel = baseCurrency ?? 'USD';

    return Scaffold(
      appBar: AppBar(
        // true → actually shows the default back arrow
        automaticallyImplyLeading: true,
        title: const Text(
          "Choose currency",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF002A5C),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              final defaultCurrency = baseCurrency ?? 'GHS';

              // If user skips, we use baseCurrency as selectedCurrency with rate 1.0
              await prefs.setString(
                  'selectedCurrency', defaultCurrency);
              await prefs.setDouble('conversionRate', 1.0);
              await prefs.setBool('isFirstAccess', false);

              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              );
            },
            child: const Text(
              "Skip",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: handleRefresh,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Default-currency info banner
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.yellow.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.black54),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "$defaultCurrencyLabel is set as the default currency. "
                            "If you prefer to pay in $defaultCurrencyLabel, you can simply skip this screen.",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Search
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: searchController,
                    onChanged: filterCurrencies,
                    decoration: const InputDecoration(
                      labelText: "Search for a currency",
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.search),
                    ),
                  ),
                ),

                // List
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredCurrencies.length,
                    itemBuilder: (context, index) {
                      final currency = filteredCurrencies[index];

                      // Hide the base/default currency from the selectable list
                      if (currency == baseCurrency) {
                        return const SizedBox.shrink();
                      }

                      final info = countryCurrencyList.firstWhere(
                        (e) => e.currencyCode == currency,
                        orElse: () => CountryInfo(
                          currencyCode: currency,
                          countryName: currency,
                          flagUrl: '',
                        ),
                      );

                      final isSelected = currency == selectedCurrency;

                      return ListTile(
                        leading: info.flagUrl.isNotEmpty
                            ? Image.network(
                                info.flagUrl,
                                width: 32,
                                height: 20,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox(width: 32, height: 20),
                              )
                            : null,
                        title: Text(
                          "${info.countryName} ($currency)",
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        tileColor: isSelected
                            ? Colors.blue.withOpacity(0.2)
                            : null,
                        onTap: () => _selectAndProceed(currency),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
