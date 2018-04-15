import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';

enum ListEventType {
  itemAdded,
  itemRemoved,
  itemMoved,
  itemChanged,
  set,
}

class ListEvent<T> {
  final ListEventType eventType;
  final int index;
  final T previousValue;

  const ListEvent({
    @required this.eventType,
    @required this.index,
    this.previousValue,
  });

  String toString() {
    return '$eventType #$index ($previousValue)';
  }
}

class ObservableList<T> extends ListBase<T> {
  Stream<ListEvent<T>> get events => _events.stream;

  int get length => _base.length;

  bool get changed => _changed;

  final List<T> _base = new List<T>();
  final StreamController<ListEvent<T>> _events =
      new StreamController<ListEvent<T>>.broadcast(sync: true);
  bool _changed = false;

  T operator [](int index) {
    return _base[index];
  }

  @override
  void add(T value) {
    insert(_base.length, value);
  }

  @override
  void addAll(Iterable<T> iterable) {
    insertAll(_base.length, iterable);
  }

  @override
  T removeAt(int index) {
    T value = _base.removeAt(index);
    _changed = true;
    _events.add(new ListEvent(
      eventType: ListEventType.itemRemoved,
      index: index,
      previousValue: value,
    ));
    return value;
  }

  @override
  void insert(int index, T element) {
    _base.insert(index, element);
    _changed = true;
    _events.add(new ListEvent(
      eventType: ListEventType.itemAdded,
      index: index,
    ));
  }

  @override
  void insertAll(int index, Iterable<T> iterable) {
    for (var item in iterable) {
      insert(index++, item);
    }
  }

  void move(int index1, int index2) {
    T element;
    if (index1 > index2) {
      element = _base.removeAt(index1);
      _base.insert(index2, element);
    } else {
      element = _base[index1];
      _base.insert(index2 + 1, element);
      _base.removeAt(index1);
    }
    _changed = true;
    _events.add(new ListEvent(
      eventType: ListEventType.itemMoved,
      index: index1,
    ));
  }

  @override
  void setAll(int index, Iterable<T> newValue) {
    _base.length = index + newValue.length;
    _base.setAll(index, newValue);
    _changed = true;
    _events.add(new ListEvent(
      eventType: ListEventType.set,
      index: index,
    ));
  }

  @override
  set length(int newLength) {
    throw new UnsupportedError('Changing ObservableList length using '
        'conventional methods is not supported. Please use methods instead');
  }

  @override
  void operator []=(int index, T value) {
    // We don't want default List<T> implementation to move items around using
    // operator[]=, because in that case we cannot trace item removal.
    // Once we override all move-inducing methods, we can change set() into
    // operator[]=.
    throw new UnsupportedError('Changing ObservableList elements using '
        'conventional methods is not supported. Please use methods instead');
  }

  // We don't override []= because that would allow us to subtly use modifying
  // methods (e.g. sort()) without immediately noticing the side effects, such
  // as itemAdded / itemRemoved / itemChanged event churn.
  void setAt(int index, T value) {
    T previousValue = _base[index];
    _base[index] = value;
    _changed = true;
    _events.add(new ListEvent(
      eventType: ListEventType.itemChanged,
      index: index,
      previousValue: previousValue,
    ));
  }

  @mustCallSuper
  void dispose() => _events.close();
}
