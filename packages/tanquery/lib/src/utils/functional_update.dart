T functionalUpdate<T>(Object updater, T input) {
  if (updater is T Function(T)) return updater(input);
  return updater as T;
}

bool shouldThrowError(Object? throwOnError, List<Object?> params) {
  if (throwOnError is bool Function(Object, Object?)) {
    return Function.apply(throwOnError, params) as bool;
  }
  if (throwOnError is bool Function(Object)) {
    return throwOnError(params.first!);
  }
  return throwOnError == true;
}
