class ExternalCoupon {
  final String id;
  final String couponCode;
  final String couponTitle;
  final String couponDescription;
  final String couponBenefits;
  final String couponTnc;
  final String externalUrl;
  final String imgUrl;
  final String videoUrl;
  final bool isEnabled;
  final bool isExclusive;
  final int createdOnTimestamp;
  final int modifiedOnTimestamp;
  final int expiryTimestamp;

  ExternalCoupon({
    required this.id,
    required this.couponCode,
    required this.couponTitle,
    required this.couponDescription,
    required this.couponBenefits,
    required this.couponTnc,
    required this.externalUrl,
    required this.imgUrl,
    required this.videoUrl,
    required this.isEnabled,
    required this.isExclusive,
    required this.createdOnTimestamp,
    required this.modifiedOnTimestamp,
    required this.expiryTimestamp,
  });

  factory ExternalCoupon.fromJson(Map<String, dynamic> json) {
    return ExternalCoupon(
      id: json['id'] ?? '',
      couponCode: json['coupon_code'] ?? '',
      couponTitle: json['coupon_title'] ?? '',
      couponDescription: json['coupon_description'] ?? '',
      couponBenefits: json['coupon_benefits'] ?? '',
      couponTnc: json['coupon_tnc'] ?? '',
      externalUrl: json['external_url'] ?? '',
      imgUrl: json['img_url'] ?? '',
      videoUrl: json['video_url'] ?? '',
      isEnabled: json['is_enabled'] ?? false,
      isExclusive: json['is_exclusive'] ?? false,
      createdOnTimestamp: json['created_on_timestamp'] ?? 0,
      modifiedOnTimestamp: json['modified_on_timestamp'] ?? 0,
      expiryTimestamp: json['expiry_timestamp'] ?? 0,
    );
  }
}

class ExternalCouponResponse {
  final List<ExternalCoupon> coupons;
  final Pagination pagination;

  ExternalCouponResponse({required this.coupons, required this.pagination});

  factory ExternalCouponResponse.fromJson(Map<String, dynamic> json) {
    var couponsList = json['response'] as List? ?? [];
    List<ExternalCoupon> coupons = couponsList
        .map((i) => ExternalCoupon.fromJson(i))
        .toList();

    return ExternalCouponResponse(
      coupons: coupons,
      pagination: Pagination.fromJson(json['pagination'] ?? {}),
    );
  }
}

class Pagination {
  final int currentPage;
  final bool hasNext;
  final bool hasPrev;
  final int totalPages;
  final int totalItems;
  final int pageSize;

  Pagination({
    required this.currentPage,
    required this.hasNext,
    required this.hasPrev,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
  });

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      currentPage: json['current_page'] ?? 1,
      hasNext: json['has_next'] ?? false,
      hasPrev: json['has_prev'] ?? false,
      totalPages: json['total_pages'] ?? 1,
      totalItems: json['total_items'] ?? 0,
      pageSize: json['page_size'] ?? 10,
    );
  }
}
