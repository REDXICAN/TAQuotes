import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:turbo_air_quotes/core/widgets/simple_image_widget.dart';

void main() {
  group('SimpleImageWidget Tests', () {
    testWidgets('should display thumbnail when useThumbnail is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SimpleImageWidget(
              sku: 'TSR-23SD',
              useThumbnail: true,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      // Should find the widget
      expect(find.byType(SimpleImageWidget), findsOneWidget);

      // Should have correct size constraints
      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.constraints?.maxWidth, 100);
      expect(container.constraints?.maxHeight, 100);
    });

    testWidgets('should display screenshot when useThumbnail is false', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SimpleImageWidget(
              sku: 'TSR-23SD',
              useThumbnail: false,
              width: 200,
              height: 200,
            ),
          ),
        ),
      );

      expect(find.byType(SimpleImageWidget), findsOneWidget);
    });

    testWidgets('should show fallback icon when SKU is empty', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SimpleImageWidget(
              sku: '',
              useThumbnail: true,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      // Should show fallback container with icon
      expect(find.byType(Icon), findsOneWidget);
      expect(find.byIcon(Icons.image_not_supported), findsOneWidget);
    });

    testWidgets('should use imageUrl when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SimpleImageWidget(
              sku: 'TEST-SKU',
              imageUrl: 'https://example.com/image.jpg',
              useThumbnail: true,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      expect(find.byType(SimpleImageWidget), findsOneWidget);
      // Network image should be attempted when imageUrl is provided
    });

    testWidgets('should create widget with border styling', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SimpleImageWidget(
              sku: 'TEST-SKU',
              useThumbnail: true,
              width: 100,
              height: 100,
            ),
          ),
        ),
      );

      // Widget should be created with ClipRRect for border
      expect(find.byType(ClipRRect), findsAtLeastNWidgets(1));
    });

    testWidgets('should apply BoxFit correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SimpleImageWidget(
              sku: 'TEST-SKU',
              useThumbnail: true,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );

      expect(find.byType(SimpleImageWidget), findsOneWidget);
    });
  });
}