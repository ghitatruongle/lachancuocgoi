import 'package:flutter_test/flutter_test.dart';
import 'package:lachancuocgoi_flutter/analysis/l3/prompt_builder.dart';

void main() {
  group('PromptBuilder — analysis prompt', () {
    test('builds analysis prompt containing the input text', () {
      const text = 'Tôi là công an, anh phải chuyển tiền.';
      final prompt = PromptBuilder.buildAnalysisPrompt(text);

      expect(prompt, contains('[START_CALL]'));
      expect(prompt, contains('[END_CALL]'));
      expect(prompt, contains(text));
      expect(prompt, contains('green'));
      expect(prompt, contains('red'));
      expect(prompt, contains('JSON'));
    });

    test('includes risk level rules in prompt', () {
      final prompt = PromptBuilder.buildAnalysisPrompt('test input');

      expect(prompt, contains('Cuộc gọi bình thường, an toàn'));
      expect(prompt, contains('Nguy hiểm, rõ ràng là lừa đảo'));
    });
  });

  group('PromptBuilder — summarization prompt', () {
    test('builds summarization prompt with examples', () {
      const text = 'Tôi gọi để xác nhận khoản vay 50 triệu.';
      final prompt = PromptBuilder.buildSummarizationPrompt(text);

      expect(prompt, contains('Tóm tắt'));
      expect(prompt, contains(text));
      expect(prompt, contains('VÍ DỤ'));
    });
  });

  group('PromptBuilder — incremental prompt', () {
    test('first message includes full system instruction', () {
      const text = 'Xin chào, tôi là nhân viên ngân hàng.';
      final prompt = PromptBuilder.buildIncrementalPrompt(text, true);

      expect(prompt, contains('real-time'));
      expect(prompt, contains(text));
      expect(prompt, contains('JSON'));
      expect(prompt, contains('green'));
      expect(prompt, contains('[Đoạn hội thoại]'));
    });

    test('continuation message uses CONTINUATION prefix', () {
      const text = 'Anh cần chuyển tiền gấp.';
      final prompt = PromptBuilder.buildIncrementalPrompt(text, false);

      expect(prompt, contains('[TIẾP TỤC]'));
      expect(prompt, contains(text));
      expect(prompt, contains('Ví dụ'));
      expect(prompt, isNot(contains('[Đoạn hội thoại]')));
    });

    test('continuation prompt includes few-shot examples', () {
      final prompt = PromptBuilder.buildIncrementalPrompt('test', false);

      expect(prompt, contains('"level": "green"'));
      expect(prompt, contains('"level": "red"'));
      expect(prompt, contains('"level": "orange"'));
      expect(prompt, contains('"level": "yellow"'));
    });
  });
}
