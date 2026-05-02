import 'package:flutter/material.dart';

import '../../services/index_service.dart';
import '../../services/store_service.dart';
import '../../services/theme/theme_manager.dart';
import 'app_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  late Future<StoreIndex> _future;
  String _query = '';
  String? _selectedCategory;
  double _minRating = 0;

  @override
  void initState() {
    super.initState();
    _future = IndexService.instance.fetchIndex();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PublicStoreApp> _filtered(List<PublicStoreApp> apps) {
    return apps.where((app) {
      final matchesQuery = _query.isEmpty ||
          app.name.toLowerCase().contains(_query) ||
          app.packageName.toLowerCase().contains(_query) ||
          app.displaySummary.toLowerCase().contains(_query);

      final matchesCategory =
          _selectedCategory == null || app.category == _selectedCategory;

      final matchesRating = _minRating == 0 || app.ratingAvg >= _minRating;

      return matchesQuery && matchesCategory && matchesRating;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return FutureBuilder<StoreIndex>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final index = snapshot.data;
        final filtered = _filtered(index?.apps ?? []);
        final categories = index?.categories ?? {};

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SearchBar(controller: _searchController),
            _FilterRow(
              categories: categories,
              selectedCategory: _selectedCategory,
              minRating: _minRating,
              onCategoryChanged: (v) => setState(() => _selectedCategory = v),
              onRatingChanged: (v) => setState(() => _minRating = v),
            ),
            Expanded(
              child: loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: colors.accentEnd,
                      ),
                    )
                  : snapshot.hasError
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              snapshot.error.toString(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: colors.textMuted,
                              ),
                            ),
                          ),
                        )
                      : filtered.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _query.isEmpty &&
                                          _selectedCategory == null &&
                                          _minRating == 0
                                      ? 'No apps in the store yet.'
                                      : 'No apps matched your filters.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: colors.textMuted,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 4, bottom: 18),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) =>
                                  _AppRow(app: filtered[index]),
                            ),
            ),
          ],
        );
      },
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(
              Icons.search_rounded,
              size: 22,
              color: colors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Search apps',
                  border: InputBorder.none,
                  isCollapsed: true,
                  hintStyle: TextStyle(
                    fontSize: 15,
                    color: colors.textMuted,
                  ),
                ),
                style: TextStyle(
                  fontSize: 15,
                  color: colors.text,
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              IconButton(
                onPressed: controller.clear,
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: colors.textMuted,
                ),
              )
            else
              const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.categories,
    required this.selectedCategory,
    required this.minRating,
    required this.onCategoryChanged,
    required this.onRatingChanged,
  });

  final Map<String, String> categories;
  final String? selectedCategory;
  final double minRating;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<double> onRatingChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: _FilterDropdown<String?>(
              value: selectedCategory,
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All categories'),
                ),
                ...categories.entries.map(
                  (e) => DropdownMenuItem<String?>(
                    value: e.key,
                    child: Text(e.value),
                  ),
                ),
              ],
              onChanged: onCategoryChanged,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FilterDropdown<double>(
              value: minRating,
              items: const [
                DropdownMenuItem(value: 0.0, child: Text('Any rating')),
                DropdownMenuItem(value: 1.0, child: Text('1★ and up')),
                DropdownMenuItem(value: 2.0, child: Text('2★ and up')),
                DropdownMenuItem(value: 3.0, child: Text('3★ and up')),
                DropdownMenuItem(value: 4.0, child: Text('4★ and up')),
                DropdownMenuItem(value: 5.0, child: Text('5★ only')),
              ],
              onChanged: (v) => onRatingChanged(v ?? 0),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: colors.surface,
          style: TextStyle(
            fontSize: 13,
            color: colors.textSoft,
            fontWeight: FontWeight.w600,
          ),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 20,
            color: colors.textMuted,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app});

  final PublicStoreApp app;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AppScreen(app: app)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
        child: Row(
          children: [
            _AppIcon(app: app, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: colors.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (app.ratingCount > 0)
                        Text(
                          '${app.displayRating} ★',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textSoft,
                          ),
                        ),
                      if (app.ratingCount > 0 && app.category.isNotEmpty)
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      if (app.category.isNotEmpty)
                        Text(
                          app.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
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
}

class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app, required this.size});

  final PublicStoreApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = SafeHavenTheme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.iconBackground,
        borderRadius: BorderRadius.circular(size * 0.22),
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: app.iconUrl.isEmpty
          ? null
          : Image.network(
              app.iconUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              loadingBuilder: (_, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const SizedBox.shrink();
              },
            ),
    );
  }
}
