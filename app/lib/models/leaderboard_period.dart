/// Which slice of time the leaderboard covers.
///
/// Mirrors the backend's ?period parameter. Held as one object so the
/// screen has a single piece of filter state to pass around and compare.
class LeaderboardPeriod {
  final String type; // all | today | week | month | year | range
  final int? year;
  final int? month; // 1-12
  final DateTime? from;
  final DateTime? to;

  const LeaderboardPeriod._(
    this.type, {
    this.year,
    this.month,
    this.from,
    this.to,
  });

  static const allTime = LeaderboardPeriod._('all');
  static const today = LeaderboardPeriod._('today');
  static const week = LeaderboardPeriod._('week');

  /// A specific calendar month. Omit both for the current month.
  factory LeaderboardPeriod.month({int? year, int? month}) =>
      LeaderboardPeriod._('month', year: year, month: month);

  /// A specific calendar year. Omit for the current year.
  factory LeaderboardPeriod.year({int? year}) =>
      LeaderboardPeriod._('year', year: year);

  factory LeaderboardPeriod.range(DateTime from, DateTime to) =>
      LeaderboardPeriod._('range', from: from, to: to);

  /// The query string the API expects, without a leading separator.
  String toQuery() {
    switch (type) {
      case 'month':
        final parts = ['period=month'];
        if (year != null) parts.add('year=$year');
        if (month != null) parts.add('month=$month');
        return parts.join('&');
      case 'year':
        return year != null ? 'period=year&year=$year' : 'period=year';
      case 'range':
        return 'period=range&from=${_iso(from!)}&to=${_iso(to!)}';
      default:
        return 'period=$type';
    }
  }

  /// What the chip row shows.
  String get shortLabel {
    switch (type) {
      case 'today':
        return 'Today';
      case 'week':
        return 'This week';
      case 'month':
        return (year == null && month == null)
            ? 'This month'
            : '${_monthNames[(month ?? 1) - 1]} ${year ?? ''}'.trim();
      case 'year':
        return year == null ? 'This year' : '$year';
      case 'range':
        return '${_short(from!)} – ${_short(to!)}';
      default:
        return 'All time';
    }
  }

  /// True when this is one of the fixed presets rather than a custom pick,
  /// so the chip row knows which chip to highlight.
  bool matchesPreset(LeaderboardPeriod preset) =>
      type == preset.type &&
      year == preset.year &&
      month == preset.month &&
      from == preset.from &&
      to == preset.to;

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _short(DateTime d) =>
      '${d.day} ${_monthAbbr[d.month - 1]}';

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const _monthAbbr = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
}
