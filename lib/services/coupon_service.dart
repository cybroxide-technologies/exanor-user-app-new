import 'package:exanor/services/api_service.dart';
import 'package:exanor/models/coupon_models.dart';

class CouponService {
  /// Fetch external coupons
  /// [query] - Optional filter conditions
  /// [page] - Page number (default: 1)
  /// [pageSize] - Items per page (default: 10, max: 15)
  static Future<ExternalCouponResponse> getExternalCoupons({
    Map<String, dynamic>? query,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await ApiService.post(
        '/external-coupon/',
        body: {'query': query ?? {}, 'page': page, 'page_size': pageSize},
        useBearerToken: true,
      );

      if (response['data'] != null) {
        return ExternalCouponResponse.fromJson(response['data']);
      } else {
        throw Exception('No data received from API');
      }
    } catch (e) {
      throw Exception('Failed to load coupons: $e');
    }
  }
}
