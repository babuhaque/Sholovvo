import 'package:sholovvo_app/core/error/failure.dart';

/// Outcome of an operation that can fail in an expected way.
///
/// Repositories return `Result<T>` so callers are forced by the type system to
/// handle failure instead of relying on try/catch discipline.
sealed class Result<T> {
  const Result();

  /// Runs [operation] and converts any thrown object into a [Failure].
  static Future<Result<T>> guard<T>(Future<T> Function() operation) async {
    try {
      return Success<T>(await operation());
    } catch (error, stackTrace) {
      return FailureResult<T>(mapExceptionToFailure(error, stackTrace));
    }
  }

  bool get isSuccess => this is Success<T>;

  bool get isFailure => this is FailureResult<T>;

  /// Successful value, or `null` when this is a failure.
  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    FailureResult<T>() => null,
  };

  /// The failure, or `null` when this is a success.
  Failure? get failureOrNull => switch (this) {
    Success<T>() => null,
    FailureResult<T>(:final failure) => failure,
  };

  /// Collapses both branches into a single value.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) {
    return switch (this) {
      Success<T>(:final value) => onSuccess(value),
      FailureResult<T>(:final failure) => onFailure(failure),
    };
  }

  /// Transforms a successful value, preserving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Success<T>(:final value) => Success<R>(transform(value)),
      FailureResult<T>(:final failure) => FailureResult<R>(failure),
    };
  }
}

/// The operation completed and produced [value].
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  String toString() => 'Success<$T>($value)';
}

/// The operation did not complete; [failure] explains why.
final class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);

  final Failure failure;

  @override
  String toString() => 'FailureResult<$T>($failure)';
}
