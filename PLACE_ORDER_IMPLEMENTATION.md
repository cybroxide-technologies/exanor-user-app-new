# Place Order Implementation

## Summary
Implemented the `/place-order` API endpoint integration in the CartScreen to enable users to place orders with all required parameters.

## Changes Made

### 1. Added `_placeOrder()` Method
**Location:** `lib/screens/cart_screen.dart` (lines 801-904)

This method handles the complete order placement flow:

#### Request Parameters:
- `coupon_code`: Empty string (can be extended for coupon support)
- `lat`: User's current latitude from `_currentLat`
- `lng`: User's current longitude from `_currentLng`
- `order_method_id`: Selected order method from `_selectedOrderMethodId`
- `payment_method_id`: Selected payment method's ID from `_selectedPaymentMethod['id']`
- `store_id`: Store ID passed via widget parameter
- `user_address_id`: Selected address ID from `_currentAddressId`

#### Features:
- **Validation**: Checks that all required fields are present before making the API call
- **Loading State**: Shows loading indicator during the API call
- **Error Handling**: Displays user-friendly error messages via SnackBar
- **Success Handling**: Shows success message and navigates back to the previous screen
- **Debug Logging**: Comprehensive console logging for debugging

### 2. Connected to "Place Order" Button
**Location:** `lib/screens/cart_screen.dart` (line 1602)

Updated the button's `onPressed` callback to call `_placeOrder` when:
- Order is placeable (`_isOrderPlaceable == true`)
- Not currently initializing (`_isInitializingOrder == false`)

## How It Works

1. **User fills cart** with products from the store
2. **Selects order method** (e.g., Delivery, Pickup) via the order method selector in the app bar
3. **Selects payment method** via the payment method selector
4. **Verifies address** is selected (already tracked in `_currentAddressId`)
5. **Order is initialized** via `/order-init/` endpoint (existing functionality)
   - If successful, `_isOrderPlaceable` is set to `true`
6. **User taps "Place Order"** button
7. **`_placeOrder()` executes**:
   - Validates all required parameters
   - Shows loading indicator
   - Makes POST request to `/place-order/`
   - Handles response (success or error)
   - Shows appropriate feedback to user

## Example Request Body

```json
{
  "coupon_code": "",
  "lat": 31.246307822526543,
  "lng": 75.70968554945745,
  "order_method_id": "09f5e7aa-9f1c-408a-9035-98a81ab5d889",
  "payment_method_id": "0fbeb9b7-05a9-4834-80be-4e3ea7c0903d",
  "store_id": "d95069ca-839d-4469-8037-a5796633deb1",
  "user_address_id": "6068c242-8d0f-4513-aaf3-401fafdad596"
}
```

## State Variables Used

- `_selectedOrderMethodId`: String? - ID of the selected order method
- `_selectedPaymentMethod`: Map<String, dynamic>? - Selected payment method object
- `_currentAddressId`: String - Currently selected address ID
- `_currentLat`: double - Current latitude
- `_currentLng`: double - Current longitude
- `_isOrderPlaceable`: bool - Whether order can be placed (set by `/order-init/`)
- `_isInitializingOrder`: bool - Loading state for order operations

## Future Enhancements

1. **Coupon Support**: Add a coupon input field and pass the coupon code
2. **Order Confirmation Screen**: Navigate to a dedicated order confirmation screen instead of just going back
3. **Order Tracking**: Implement order tracking functionality after successful placement
4. **Payment Gateway Integration**: If needed, integrate payment gateway before final order placement
5. **Retry Logic**: Add retry mechanism for failed orders

## Testing

To test the implementation:

1. Run the app
2. Add items to cart from a store
3. Ensure an address is selected
4. Select an order method (Delivery/Pickup)
5. Select a payment method
6. Wait for order initialization to complete
7. Tap "Place Order" button
8. Verify the order is placed successfully

## Notes

- All parameters are sourced from the existing CartScreen state
- The implementation follows the existing code patterns in the file
- Error handling includes both API errors and validation errors
- Loading states are properly managed to prevent duplicate submissions
