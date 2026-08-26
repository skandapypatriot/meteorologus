import 'package:flutter/material.dart';

class PageIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final Color color;

  const PageIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: color.withAlpha(isActive ? 220 : 75),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
