import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    // Premium Shimmer Colors
    final baseColor = isDark
        ? const Color(0xFF2C2C2C)
        : const Color(0xFFE0E0E0);
    final highlightColor = isDark
        ? const Color(0xFF3D3D3D)
        : const Color(0xFFF5F5F5);
    final containerColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return SliverPadding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 110),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 20, left: 4, right: 4),
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withOpacity(0.4)
                      : const Color(0xFF1F4C6B).withOpacity(0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              period: const Duration(milliseconds: 1500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Image Placeholder (1.85 Aspect Ratio)
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 1.85,
                        child: Container(
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      // Featured Tag Placeholder (Top Left)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          width: 60,
                          height: 20,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      // Favorite Icon Placeholder (Top Right)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: baseColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // Rating/Time Pill Placeholder (Bottom Left)
                      Positioned(
                        bottom: 12,
                        left: 12,
                        child: Container(
                          width: 100,
                          height: 24,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Dashed Line Simulation (Thin solid line for skeleton)
                  Container(
                    height: 1,
                    width: double.infinity,
                    color: baseColor,
                  ),

                  // Details Content
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Container(
                          width: double.infinity,
                          height: 20,
                          margin: const EdgeInsets.only(right: 60),
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Category • Area
                        Container(
                          width: 150,
                          height: 14,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Coupon Chips Row
                        Row(
                          children: [
                            Container(
                              width: 100,
                              height: 28,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 80,
                              height: 28,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }, childCount: 4),
      ),
    );
  }
}

class CategorySkeleton extends StatelessWidget {
  const CategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark
        ? const Color(0xFF2C2C2C)
        : const Color(0xFFE0E0E0);
    final highlightColor = isDark
        ? const Color(0xFF3D3D3D)
        : const Color(0xFFF5F5F5);

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      scrollDirection: Axis.horizontal,
      itemCount: 6,
      physics:
          const NeverScrollableScrollPhysics(), // Disable scrolling for skeleton
      separatorBuilder: (context, index) => const SizedBox(width: 16),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          period: const Duration(milliseconds: 1500),
          child: SizedBox(
            width: 56,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.transparent,
                      width: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 40,
                  height: 10,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
