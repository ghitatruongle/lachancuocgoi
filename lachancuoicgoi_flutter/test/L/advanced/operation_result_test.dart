import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/core/operation_result.dart';

void main() {
  group('Result.success', () {
    test('holds the provided value', () {
      final result = Result.success(42);
      expect(result.value, 42);
    });

    test('isSuccess is true', () {
      final result = Result.success('hello');
      expect(result.isSuccess, isTrue);
    });

    test('isFailure is false', () {
      final result = Result.success(true);
      expect(result.isFailure, isFalse);
    });

    test('error is null', () {
      final result = Result.success(3.14);
      expect(result.error, isNull);
    });

    test('stackTrace is null', () {
      final result = Result.success('data');
      expect(result.stackTrace, isNull);
    });

    test('works with complex types', () {
      final map = {'key': 'value', 'count': 5};
      final result = Result.success(map);
      expect(result.value, map);
      expect(result.isSuccess, isTrue);
    });

    test('works with list type', () {
      final list = [1, 2, 3];
      final result = Result.success(list);
      expect(result.value, [1, 2, 3]);
      expect(result.isSuccess, isTrue);
    });
  });

  group('Result.failure', () {
    test('holds the provided error', () {
      final result = Result.failure<int>('something went wrong');
      expect(result.error, 'something went wrong');
    });

    test('isSuccess is false', () {
      final result = Result.failure<String>('err');
      expect(result.isSuccess, isFalse);
    });

    test('isFailure is true', () {
      final result = Result.failure<double>('err');
      expect(result.isFailure, isTrue);
    });

    test('value is null', () {
      final result = Result.failure<bool>('err');
      expect(result.value, isNull);
    });

    test('stores stackTrace when provided', () {
      final trace = StackTrace.current;
      final result = Result.failure<int>('err', trace);
      expect(result.stackTrace, same(trace));
    });

    test('stackTrace is null when not provided', () {
      final result = Result.failure<int>('err');
      expect(result.stackTrace, isNull);
    });

    test('works with Exception objects', () {
      const exception = FormatException('bad format');
      final result = Result.failure<String>(exception);
      expect(result.error, same(exception));
    });
  });

  group('Result.getOrThrow', () {
    test('returns value on success', () {
      final result = Result.success(42);
      expect(result.getOrThrow(), 42);
    });

    test('returns string value on success', () {
      final result = Result.success('hello');
      expect(result.getOrThrow(), 'hello');
    });

    test('throws error on failure', () {
      final result = Result.failure<int>('boom');
      expect(() => result.getOrThrow(), throwsA('boom'));
    });

    test('throws exception object on failure', () {
      final exception = StateError('bad state');
      final result = Result.failure<int>(exception);
      expect(() => result.getOrThrow(), throwsA(same(exception)));
    });

    test('throws and catch preserves error type', () {
      final result = Result.failure<String>('err');
      try {
        result.getOrThrow();
        fail('Should have thrown');
      } catch (e) {
        expect(e, 'err');
      }
    });
  });

  group('Result.fold', () {
    test('calls onSuccess on success with the value', () {
      final result = Result.success(42);
      final folded = result.fold(
        onSuccess: (v) => 'success: $v',
        onFailure: (e, st) => 'failure: $e',
      );
      expect(folded, 'success: 42');
    });

    test('calls onFailure on failure with error and stackTrace', () {
      final trace = StackTrace.current;
      final result = Result.failure<int>('err', trace);
      String? capturedError;
      StackTrace? capturedTrace;

      final folded = result.fold(
        onSuccess: (v) => 'success',
        onFailure: (e, st) {
          capturedError = e as String;
          capturedTrace = st;
          return 'failure';
        },
      );

      expect(folded, 'failure');
      expect(capturedError, 'err');
      expect(capturedTrace, same(trace));
    });

    test('returns different types from each branch', () {
      final successResult = Result.success(10);
      final failureResult = Result.failure<int>('err');

      int successFold = successResult.fold(
        onSuccess: (v) => v,
        onFailure: (e, st) => -1,
      );
      int failureFold = failureResult.fold(
        onSuccess: (v) => v,
        onFailure: (e, st) => -1,
      );

      expect(successFold, 10);
      expect(failureFold, -1);
    });

    test('fold with void return type', () {
      int? captured;
      final result = Result.success(99);
      result.fold(
        onSuccess: (v) => captured = v,
        onFailure: (e, st) => captured = -1,
      );
      expect(captured, 99);
    });

    test('failure fold receives null stackTrace when not provided', () {
      StackTrace? capturedTrace;
      final result = Result.failure<int>('err');
      result.fold(
        onSuccess: (v) {},
        onFailure: (e, st) {
          capturedTrace = st;
        },
      );
      expect(capturedTrace, isNull);
    });
  });

  group('Result edge cases', () {
    test('success with empty string is still success', () {
      final result = Result.success('');
      expect(result.isSuccess, isTrue);
      expect(result.value, '');
    });

    test('success with zero is still success', () {
      final result = Result.success(0);
      expect(result.isSuccess, isTrue);
      expect(result.value, 0);
    });

    test('success with false is still success', () {
      final result = Result.success(false);
      expect(result.isSuccess, isTrue);
      expect(result.value, isFalse);
    });

    test('failure with empty string error', () {
      final result = Result.failure<int>('');
      expect(result.isFailure, isTrue);
      expect(result.error, '');
    });

    test('success and failure are mutually exclusive', () {
      final success = Result.success(1);
      final failure = Result.failure<int>('err');

      expect(success.isSuccess, isNot(failure.isSuccess));
      expect(success.isFailure, isNot(failure.isFailure));
    });
  });
}
