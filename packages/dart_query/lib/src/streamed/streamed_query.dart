import 'dart:async';
import '../models/types.dart';
import '../query/query.dart';

typedef StreamFn<TChunk> = Stream<TChunk> Function();
typedef StreamReducer<TData, TChunk> = TData Function(TData accumulated, TChunk chunk);

QueryFn<TData> streamedQuery<TChunk, TData>({
  required StreamFn<TChunk> streamFn,
  required StreamReducer<TData, TChunk> reducer,
  required TData initialValue,
  RefetchMode refetchMode = RefetchMode.reset,
  void Function(TData data)? onData,
}) {
  return () async {
    var result = initialValue;
    final stream = streamFn();

    await for (final chunk in stream) {
      result = reducer(result, chunk);
      onData?.call(result);
    }

    return result;
  };
}
