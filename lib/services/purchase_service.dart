import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'premium_service.dart';

class PurchaseService {
  static const String monthlyProductId = 'carpecarb_premium_monthlysub';
  static const String yearlyProductId = 'carpecarb_premium_yearly';

  final InAppPurchase _iap = InAppPurchase.instance;
  FirebaseFunctions? _functions;

  FirebaseFunctions get _firebaseFunctions =>
      _functions ??= FirebaseFunctions.instance;

  Set<String> get _productIds => {monthlyProductId, yearlyProductId};

  Future<bool> isStoreAvailable() {
    return _iap.isAvailable();
  }

  Future<Map<String, ProductDetails>> queryPremiumProducts() async {
    final response = await _iap.queryProductDetails(_productIds);
    if (response.error != null) {
      throw Exception(response.error!.message);
    }

    return {
      for (final product in response.productDetails) product.id: product,
    };
  }

  String productIdForPlan(String plan) {
    if (plan == PremiumService.monthlyPlan) return monthlyProductId;
    if (plan == PremiumService.yearlyPlan) return yearlyProductId;
    throw ArgumentError('Unknown premium plan: $plan');
  }

  String? planForProductId(String productId) {
    if (productId == monthlyProductId) return PremiumService.monthlyPlan;
    if (productId == yearlyProductId) return PremiumService.yearlyPlan;
    return null;
  }

  Future<String?> _validateReceipt(
    PurchaseDetails purchase, {
    String? expectedProductId,
  }) async {
    final receiptData = purchase.verificationData.serverVerificationData;
    if (receiptData.isEmpty) {
      throw Exception('App Store receipt data is missing.');
    }

    try {
      final callable = _firebaseFunctions.httpsCallable(
        'validateAppStoreReceipt',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );

      final result = await callable.call<Map<String, dynamic>>({
        'receiptData': receiptData,
        if (expectedProductId != null) 'expectedProductId': expectedProductId,
      });

      final data = Map<String, dynamic>.from(result.data);
      if (data['isValid'] != true) {
        final reason = data['reason']?.toString();
        if (reason == 'product-mismatch') {
          final found = data['productId']?.toString() ?? 'unknown';
          throw Exception(
            'Receipt was valid but for a different product ($found).',
          );
        }
        if (reason == 'no-active-subscription') {
          throw Exception(
            'No active subscription was found in the App Store receipt.',
          );
        }
        throw Exception('Receipt validation failed (${reason ?? 'unknown'}).');
      }

      final productId = data['productId']?.toString();
      if (productId == null || productId.isEmpty) {
        return null;
      }

      return productId;
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'validateAppStoreReceipt failed: code=${e.code} message=${e.message}',
      );

      switch (e.code) {
        case 'unauthenticated':
        case 'permission-denied':
          throw Exception(
            'Receipt verification is blocked by backend permissions. Please update Cloud Function invoker settings.',
          );
        case 'invalid-argument':
          throw Exception('The App Store receipt was invalid.');
        case 'failed-precondition':
          throw Exception(
            e.message ??
                'The App Store could not confirm an active premium subscription.',
          );
        default:
          throw Exception('Could not verify App Store purchase right now.');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Could not verify App Store purchase right now.');
    }
  }

  Future<bool> purchasePlan(String plan) async {
    final productId = productIdForPlan(plan);
    final products = await queryPremiumProducts();
    final product = products[productId];
    if (product == null) {
      throw Exception('Product not found in App Store Connect: $productId');
    }

    final completer = Completer<bool>();
    late final StreamSubscription<List<PurchaseDetails>> sub;

    sub = _iap.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.productID != productId) continue;

          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            try {
              final validatedProductId = await _validateReceipt(
                purchase,
                expectedProductId: productId,
              );

              if (purchase.pendingCompletePurchase) {
                await _iap.completePurchase(purchase);
              }
              if (!completer.isCompleted) {
                completer.complete(validatedProductId == productId);
              }
            } catch (e) {
              if (purchase.pendingCompletePurchase) {
                await _iap.completePurchase(purchase);
              }
              if (!completer.isCompleted) completer.completeError(e);
            }
          } else if (purchase.status == PurchaseStatus.error ||
              purchase.status == PurchaseStatus.canceled) {
            if (purchase.pendingCompletePurchase) {
              await _iap.completePurchase(purchase);
            }
            if (!completer.isCompleted) {
              if (purchase.status == PurchaseStatus.canceled) {
                completer.completeError(
                  Exception('Purchase was canceled in App Store.'),
                );
              } else {
                final purchaseError = purchase.error;
                final msg =
                    purchaseError?.message.trim();
                completer.completeError(
                  Exception(
                    msg == null || msg.isEmpty
                        ? 'App Store reported a purchase error.'
                        : msg,
                  ),
                );
              }
            }
          }
        }
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('Purchase stream error: ${e.toString()}'),
          );
        }
      },
      cancelOnError: false,
    );

    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );

    if (!started) {
      await sub.cancel();
      throw Exception('Could not start App Store purchase flow.');
    }

    try {
      return await completer.future.timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw Exception('Timed out waiting for App Store purchase confirmation.');
    } finally {
      await sub.cancel();
    }
  }

  Future<String?> restorePremiumPlan() async {
    final completer = Completer<String?>();
    late final StreamSubscription<List<PurchaseDetails>> sub;

    sub = _iap.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          final plan = planForProductId(purchase.productID);
          if (plan == null) continue;

          if (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored) {
            try {
              final validatedProductId = await _validateReceipt(purchase);

              if (purchase.pendingCompletePurchase) {
                await _iap.completePurchase(purchase);
              }

              final validatedPlan = validatedProductId == null
                  ? null
                  : planForProductId(validatedProductId);

              if (validatedPlan == null) {
                continue;
              }

              if (!completer.isCompleted) completer.complete(validatedPlan);
            } catch (e) {
              if (purchase.pendingCompletePurchase) {
                await _iap.completePurchase(purchase);
              }
              if (!completer.isCompleted) completer.completeError(e);
            }
          }
        }
      },
      onError: (_) {
        if (!completer.isCompleted) completer.complete(null);
      },
      cancelOnError: false,
    );

    await _iap.restorePurchases();

    try {
      return await completer.future.timeout(const Duration(seconds: 20));
    } on TimeoutException {
      return null;
    } finally {
      await sub.cancel();
    }
  }
}
