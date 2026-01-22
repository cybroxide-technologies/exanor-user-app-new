class Coupon {
  final String id;
  final String couponCode;
  final String imgUrl;
  final double amount;
  final bool isPercentDiscountType;
  final bool isAmountDiscountType;
  final String description;
  final int expiryTimestamp;
  final double minimumAmount;
  final double maximumDiscountAmountLimit;
  final bool freeShipping;

  Coupon({
    required this.id,
    required this.couponCode,
    required this.imgUrl,
    required this.amount,
    required this.isPercentDiscountType,
    required this.isAmountDiscountType,
    required this.description,
    required this.expiryTimestamp,
    required this.minimumAmount,
    required this.maximumDiscountAmountLimit,
    required this.freeShipping,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] ?? '',
      couponCode: json['coupon_code'] ?? '',
      imgUrl: json['img_url'] ?? '',
      amount: _parseDouble(json['amount']),
      isPercentDiscountType: json['is_percent_discount_type'] ?? false,
      isAmountDiscountType: json['is_amount_discount_type'] ?? false,
      description: json['description'] ?? '',
      expiryTimestamp: json['expiry_timestamp'] ?? 0,
      minimumAmount: _parseDouble(json['minimum_amount']),
      maximumDiscountAmountLimit: _parseDouble(
        json['maximum_discount_amount_limit'],
      ),
      freeShipping: json['free_shipping'] ?? false,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

class Store {
  final String id;
  final String storeName;
  final String categoryId;
  final String category;
  final String fulfillmentSpeed;
  final String city;
  final String area;
  final String? weburl;
  final double averageRating;
  final int ratingCount;
  final String storeCityLocation;
  final String achievementText;
  final String offerTypeText;
  final String offerText;
  final String offerConditionText;
  final String bottomOfferTitle;
  final String bottomOfferSubtitle;
  final String bottomOfferImg;
  final bool isSponsored;
  final bool isFeatured;
  final String storeLogoImgUrl;
  final String storeBannerImgUrl;
  final List<Coupon> coupons;

  Store({
    required this.id,
    required this.storeName,
    required this.categoryId,
    required this.category,
    required this.fulfillmentSpeed,
    required this.city,
    required this.area,
    this.weburl,
    required this.averageRating,
    required this.ratingCount,
    required this.storeCityLocation,
    required this.achievementText,
    required this.offerTypeText,
    required this.offerText,
    required this.offerConditionText,
    required this.bottomOfferTitle,
    required this.bottomOfferSubtitle,
    required this.bottomOfferImg,
    required this.isSponsored,
    required this.isFeatured,
    required this.storeLogoImgUrl,
    required this.storeBannerImgUrl,
    required this.coupons,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] ?? '',
      storeName: json['store_name'] ?? '',
      categoryId: json['cartegory_id'] ?? '', // Note typo in API response
      category: json['category'] ?? '',
      fulfillmentSpeed: json['fulfillment_speed'] ?? '',
      city: json['city'] ?? '',
      area: json['area'] ?? '',
      weburl: json['weburl'] == 'undefined' ? null : json['weburl'],
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['rating_count'] ?? 0,
      storeCityLocation: json['store_city_location'] ?? '',
      achievementText: json['achievement_text'] ?? '',
      offerTypeText: json['offer_type_text'] ?? '',
      offerText: json['offer_text'] ?? '',
      offerConditionText: json['offer_condition_text'] ?? '',
      bottomOfferTitle: json['bottom_offer_title'] ?? '',
      bottomOfferSubtitle: json['bottom_offer_subtitle'] ?? '',
      bottomOfferImg: json['bottom_offer_img'] ?? '',
      isSponsored: json['is_sponsored'] ?? false,
      isFeatured: json['is_featured'] ?? false,
      storeLogoImgUrl: json['store_logo_img_url'] ?? '',
      storeBannerImgUrl: json['store_banner_img_url'] ?? '',
      coupons:
          (json['coupons'] as List<dynamic>?)
              ?.map((e) => Coupon.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
