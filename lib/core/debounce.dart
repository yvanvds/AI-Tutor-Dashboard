import 'dart:async';

class Debouncer {
  Debouncer(this.delay);
  final Duration delay;
  Timer? _t;

  void run(void Function() action) {
    _t?.cancel();
    _t = Timer(delay, action);
  }

  void dispose() => _t?.cancel();
}
