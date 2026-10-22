import 'package:flutter/material.dart';


PageResult<T> paginateLocally<T>(List<T> all, int page, {int pageSize = 20}) {
  final totalPages = all.isEmpty ? 1 : (all.length / pageSize).ceil();
  final start = (page - 1) * pageSize;
  if (start >= all.length) {
    return PageResult<T>(items: [], page: page, totalPages: totalPages, hasMore: false);
  }
  final end = (start + pageSize) > all.length ? all.length : (start + pageSize);
  return PageResult<T>(
    items: all.sublist(start, end),
    page: page,
    totalPages: totalPages,
    hasMore: page < totalPages,
  );
}


class PageResult<T> {
  final List<T> items;
  final int page;
  final int? totalPages;
  final bool hasMore;

  PageResult({
    required this.items,
    required this.page,
    this.totalPages,
    required this.hasMore,
  });
}

class PaginatedListView<T> extends StatefulWidget {

  final Future<PageResult<T>> Function(int page, String search) fetchPage;

  final Widget Function(BuildContext context, T item, int index) itemBuilder;


  final bool showSearch;
  final String searchHint;

  final String emptyMessage;

  final Color primaryColor;

  final EdgeInsetsGeometry listPadding;

  const PaginatedListView({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.showSearch = false,
    this.searchHint = 'Search',
    this.emptyMessage = 'No items found.',
    this.primaryColor = const Color(0xFF0D7377),
    this.listPadding = const EdgeInsets.all(16),
  });

  @override
  State<PaginatedListView<T>> createState() => PaginatedListViewState<T>();
}

class PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  List<T> _items = [];
  int _page = 1;
  int? _totalPages;
  bool _hasMore = true;
  bool _loading = true;
  String? _error;
  String _search = '';
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _load(1);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }


  Future<void> refresh() => _load(1);

  Future<void> _load(int page) async {
    if (page < 1) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.fetchPage(page, _search);
      if (!mounted) return;
      setState(() {
        _items = result.items;
        _page = result.page;
        _totalPages = result.totalPages;
        _hasMore = result.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _runSearch(String q) {
    _search = q.trim();
    _load(1);
  }

  @override
  Widget build(BuildContext context) {
    final canGoNext = _totalPages != null ? _page < _totalPages! : _hasMore;

    return Column(
      children: [
        if (widget.showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: widget.searchHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onSubmitted: _runSearch,
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              if (_error != null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => _load(_page),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (_items.isEmpty && !_loading)
                Center(
                  child: Text(
                    widget.emptyMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                )
              else
                RefreshIndicator(
                  onRefresh: () => _load(_page),
                  color: widget.primaryColor,
                  child: ListView.builder(
                    padding: widget.listPadding,
                    itemCount: _items.length,
                    itemBuilder: (context, i) =>
                        widget.itemBuilder(context, _items[i], i),
                  ),
                ),
              if (_loading) const Center(child: CircularProgressIndicator()),
            ],
          ),
        ),
        // ---- Page N of M navigation ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: (_page > 1 && !_loading) ? () => _load(_page - 1) : null,
                icon: const Icon(Icons.chevron_left),
                label: const Text('Previous'),
              ),
              Text(
                _totalPages != null ? 'Page $_page of $_totalPages' : 'Page $_page',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              TextButton.icon(
                onPressed: (canGoNext && !_loading) ? () => _load(_page + 1) : null,
                icon: const Icon(Icons.chevron_right),
                label: const Text('Next'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}