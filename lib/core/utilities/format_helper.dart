import 'package:intl/intl.dart';

class FormatHelper {
  static final _money = NumberFormat('#,##0.00');
  static final _dateTime = DateFormat('MMM d, yyyy • h:mm a');

  static String money(double v, String symbol) => '$symbol${_money.format(v)}';
  static String dateTime(DateTime d) => _dateTime.format(d);
}
