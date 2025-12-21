extension ListContains<T> on List<T> {
  void replaceWhere(bool Function(T element) test, T newElement) {
    for (var i = 0; i < length; i++) {
      if (test(this[i])) {
        this[i] = newElement;
      }
    }
  }

  int? containsWithId(
    bool Function(T element) test,
  ) {
    for (var element in this) {
      if (test(element)) return indexOf(element);
    }
    return null;
  }

  T? containsWithCondition(
    bool Function(T element) test,
  ) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }

  bool hasIndex(int index) {
    if (length == 0 || index < 0 || index >= length) {
      return false;
    }
    return true;
  }
}
