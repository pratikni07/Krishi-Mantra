import 'package:flutter/material.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import 'skeleton_widgets.dart';

/// Skeleton loading state for the carousel slider section
class SkeletonCarouselSection extends StatelessWidget {
  const SkeletonCarouselSection({super.key});

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final carouselHeight =
        ResponsiveUtils.responsive(mobile: 200.0, tablet: 280.0);

    return Container(
      height: carouselHeight,
      margin: EdgeInsets.symmetric(vertical: AppSizes.paddingM * 0.5),
      child: const SkeletonCarouselItem(),
    );
  }
}

/// Skeleton loading state for the trending reels section
class SkeletonTrendingReelsSection extends StatelessWidget {
  const SkeletonTrendingReelsSection({super.key});

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingL,
            vertical: AppSizes.paddingM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonContainer(
                width: 140,
                height: 20,
                borderRadius: 4,
              ),
              SkeletonContainer(
                width: 60,
                height: 16,
                borderRadius: 4,
              ),
            ],
          ),
        ),
        // Reel cards
        SizedBox(
          height: ResponsiveUtils.responsive(mobile: 180.0, tablet: 220.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            itemCount: 4,
            itemBuilder: (context, index) {
              return const SkeletonReelCard();
            },
          ),
        ),
      ],
    );
  }
}

/// Skeleton loading state for the hot products section
class SkeletonHotProductsSection extends StatelessWidget {
  const SkeletonHotProductsSection({super.key});

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingL,
            vertical: AppSizes.paddingM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonContainer(
                width: 120,
                height: 20,
                borderRadius: 4,
              ),
              SkeletonContainer(
                width: 60,
                height: 16,
                borderRadius: 4,
              ),
            ],
          ),
        ),
        // Product cards
        SizedBox(
          height: ResponsiveUtils.responsive(mobile: 200.0, tablet: 240.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            itemCount: 4,
            itemBuilder: (context, index) {
              return const SkeletonProductCard();
            },
          ),
        ),
        SizedBox(height: AppSizes.paddingL),
      ],
    );
  }
}

/// Skeleton loading state for the trending hashtags section
class SkeletonTrendingHashtagsSection extends StatelessWidget {
  const SkeletonTrendingHashtagsSection({super.key});

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: EdgeInsets.only(
            left: AppSizes.paddingL,
            right: AppSizes.paddingL,
            top: AppSizes.paddingS,
            bottom: AppSizes.paddingS,
          ),
          child: SkeletonContainer(
            width: 140,
            height: 20,
            borderRadius: 4,
          ),
        ),
        // Hashtag chips
        SizedBox(
          height: ResponsiveUtils.responsive(mobile: 38.0, tablet: 48.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            itemCount: 5,
            itemBuilder: (context, index) {
              // Varying widths for more realistic look
              final widths = [80.0, 100.0, 70.0, 90.0, 85.0];
              return SkeletonHashtagChip(width: widths[index]);
            },
          ),
        ),
      ],
    );
  }
}

/// Skeleton loading state for the top feeds section
class SkeletonTopFeedsSection extends StatelessWidget {
  final int count;

  const SkeletonTopFeedsSection({super.key, this.count = 2});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (index) => const SkeletonFeedCard(),
      ),
    );
  }
}

/// Skeleton loading state for the latest schemes section
class SkeletonLatestSchemesSection extends StatelessWidget {
  const SkeletonLatestSchemesSection({super.key});

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingL,
            vertical: AppSizes.paddingM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonContainer(
                width: 160,
                height: 20,
                borderRadius: 4,
              ),
              SkeletonContainer(
                width: 60,
                height: 16,
                borderRadius: 4,
              ),
            ],
          ),
        ),
        // Scheme cards
        SizedBox(
          height: ResponsiveUtils.responsive(mobile: 160.0, tablet: 180.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            itemCount: 3,
            itemBuilder: (context, index) {
              return const SkeletonSchemeCard();
            },
          ),
        ),
      ],
    );
  }
}

/// Skeleton loading state for the testimonials section
class SkeletonTestimonialsSection extends StatelessWidget {
  const SkeletonTestimonialsSection({super.key});

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Column(
      children: [
        // Title
        Container(
          margin: EdgeInsets.only(
            top: AppSizes.paddingL,
            bottom: AppSizes.paddingM,
          ),
          child: SkeletonContainer(
            width: 140,
            height: 24,
            borderRadius: 4,
          ),
        ),
        // Testimonial cards
        SizedBox(
          height: ResponsiveUtils.responsive(mobile: 160.0, tablet: 200.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            itemCount: 2,
            itemBuilder: (context, index) {
              return const SkeletonTestimonialCard();
            },
          ),
        ),
      ],
    );
  }
}

/// Complete home screen skeleton - shows all sections in loading state
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Carousel skeleton
          const SkeletonCarouselSection(),
          SizedBox(height: AppSizes.paddingM),

          // Services title skeleton
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            child: SkeletonContainer(
              width: 100,
              height: 24,
              borderRadius: 4,
            ),
          ),
          SizedBox(height: AppSizes.paddingM),

          // Services grid skeleton
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    SkeletonContainer(
                      width: 48,
                      height: 48,
                      borderRadius: 12,
                    ),
                    const SizedBox(height: 6),
                    SkeletonContainer(
                      width: 50,
                      height: 10,
                      borderRadius: 4,
                    ),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: AppSizes.paddingL),

          // Trending reels skeleton
          const SkeletonTrendingReelsSection(),
          SizedBox(height: AppSizes.paddingM),

          // Hot products skeleton
          const SkeletonHotProductsSection(),

          // Trending hashtags skeleton
          const SkeletonTrendingHashtagsSection(),
          SizedBox(height: AppSizes.paddingM),

          // Ad banner skeleton
          const SkeletonAdBanner(),

          // Top feeds skeleton
          const SkeletonTopFeedsSection(count: 2),
          SizedBox(height: AppSizes.paddingM),

          // Latest schemes skeleton
          const SkeletonLatestSchemesSection(),
          SizedBox(height: AppSizes.paddingL),
        ],
      ),
    );
  }
}
