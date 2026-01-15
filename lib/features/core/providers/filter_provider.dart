import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'filter_provider.g.dart';

/// Represents a date range filter
class DateRange {
  const DateRange({
    required this.start,
    required this.end,
  });

  final DateTime? start;
  final DateTime? end;

  bool get hasFilter => start != null || end != null;

  @override
  String toString() => 'DateRange(start: $start, end: $end)';
}

/// Global filter state for cross-table filtering
@Riverpod(keepAlive: true)
class GlobalFilter extends _$GlobalFilter {
  @override
  ({String? userId, DateRange dateRange}) build() => (
        userId: null,
        dateRange: const DateRange(start: null, end: null),
      );

  /// Set the selected user ID
  void setUserId(String? userId) {
    state = (userId: userId, dateRange: state.dateRange);
  }

  /// Set the date range
  void setDateRange(DateRange dateRange) {
    state = (userId: state.userId, dateRange: dateRange);
  }

  /// Clear all filters
  void clearFilters() {
    state = (
      userId: null,
      dateRange: const DateRange(start: null, end: null),
    );
  }

  /// Check if any filter is active
  bool get hasActiveFilters =>
      state.userId != null || state.dateRange.hasFilter;
}
