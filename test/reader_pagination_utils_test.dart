import 'package:flutter_test/flutter_test.dart';
import 'package:mr/pages/reader/reader_pagination_utils.dart';

void main() {
  group('ReaderPaginationUtils', () {
    test('pageIndexToFraction and fractionToPageIndex are inverse', () {
      const pageCount = 12;
      for (var page = 0; page < pageCount; page++) {
        final fraction = ReaderPaginationUtils.pageIndexToFraction(
          page,
          pageCount,
        );
        expect(
          ReaderPaginationUtils.fractionToPageIndex(fraction, pageCount),
          page,
        );
      }
    });

    test('single page always maps to index 0', () {
      expect(ReaderPaginationUtils.fractionToPageIndex(0.9, 1), 0);
      expect(ReaderPaginationUtils.pageIndexToFraction(0, 1), 0.0);
    });

    test('estimateCharOffsetFromFraction clamps', () {
      expect(
        ReaderPaginationUtils.estimateCharOffsetFromFraction(1.5, 100),
        99,
      );
      expect(
        ReaderPaginationUtils.estimateCharOffsetFromFraction(-1, 100),
        0,
      );
    });

    test('findSentenceStartIndex walks back to punctuation', () {
      const text = '第一句。第二句！第三句？';
      final start = ReaderPaginationUtils.findSentenceStartIndex(text, 10);
      expect(start, greaterThan(0));
      expect(text.substring(start).startsWith('第三句'), isTrue);
    });

    test('findSentenceStartIndex respects English period boundaries', () {
      const text =
          'First sentence ends here. Second sentence begins afterward.';
      final start = ReaderPaginationUtils.findSentenceStartIndex(text, 40);
      expect(text.substring(start), startsWith('Second sentence'));
    });
  });
}
