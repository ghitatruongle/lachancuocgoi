import 'dart:async';
import 'call_history.dart';

abstract class CallHistoryRepository {
  Stream<List<CallHistory>> watchAll();
  Stream<void> get changes;
  Future<int> insert(CallHistory callHistory);
  Future<List<CallHistory>> getAll();
  Future<List<CallHistory>> getAllPaginated({int limit = 20, int offset = 0});
  Future<int> count();
  Future<List<CallHistory>> search(
    String query, {
    int limit = 20,
    int offset = 0,
  });
  Future<int> searchCount(String query);
  Future<CallHistory?> getById(int id);
  Future<void> deleteAll();
  Future<void> deleteById(int id);
  Future<void> updateRiskLevel(int id, String riskLevel);
  Future<void> update(CallHistory callHistory);
  Future<void> dispose();
}
