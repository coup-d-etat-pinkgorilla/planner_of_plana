import 'dart:collection';

/// Observe the Mock repository write boundary without changing scanner callers.
/// Metadata writes reuse their current buckets and do not emit current events.
class MockRepositoryCurrentMap extends MapBase<String, Map<String, dynamic>> {
  MockRepositoryCurrentMap(this.beforeWrite);
  final void Function(String, Map<String, dynamic>?, Map<String, dynamic>)
  beforeWrite;
  final Map<String, Map<String, dynamic>> _values = {};

  @override
  Map<String, dynamic>? operator [](Object? key) => _values[key];
  @override
  void operator []=(String key, Map<String, dynamic> value) {
    beforeWrite(key, _values[key], value);
    _values[key] = value;
  }

  @override
  Iterable<String> get keys => _values.keys;
  @override
  void clear() => _values.clear();
  @override
  Map<String, dynamic>? remove(Object? key) => _values.remove(key);
}
