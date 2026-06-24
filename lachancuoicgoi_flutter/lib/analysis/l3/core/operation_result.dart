class Result<T> {
  const Result._({this.value, this.error, this.stackTrace});

  final T? value;
  final Object? error;
  final StackTrace? stackTrace;

  bool get isSuccess => error == null;

  bool get isFailure => error != null;

  static Result<T> success<T>(T value) {
    return Result<T>._(value: value);
  }

  static Result<T> failure<T>(Object error, [StackTrace? stackTrace]) {
    return Result<T>._(error: error, stackTrace: stackTrace);
  }

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Object error, StackTrace? stackTrace) onFailure,
  }) {
    if (isSuccess) {
      return onSuccess(value as T);
    }
    return onFailure(error!, stackTrace);
  }

  T getOrThrow() {
    if (isSuccess) {
      return value as T;
    }
    throw error!;
  }
}
