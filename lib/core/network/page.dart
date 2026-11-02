/// One page of a paginated list.
class Page<T> {
  const new({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    this.total,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int? total;

  bool get hasMore => currentPage < lastPage;
}
