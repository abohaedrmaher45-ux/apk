/// GraphQL queries and mutations for Bagisto checkout flow
/// Based on the actual Bagisto Headless Commerce GraphQL schema

class CheckoutQueries {
  /// Get the customer's saved addresses.
  ///
  /// VERIFIED against `shop/customer/addresses.graphql`:
  ///   addresses(input: FilterCustomerAddressInput): [Address!] @paginate(type: "PAGINATOR")
  ///
  /// `collectionGetCheckoutAddresses` does NOT exist on this schema (nor does
  /// the Relay `edges/node` wrapper it used). A PAGINATOR returns
  /// `{ paginatorInfo, data }`.
  static const String getCheckoutAddresses = r'''
    query addresses($first: Int, $page: Int) {
      addresses(first: $first, page: $page, input: {}) {
        paginatorInfo {
          count
          currentPage
          lastPage
          total
        }
        data {
          id
          addressType
          firstName
          lastName
          companyName
          address
          city
          state
          country
          postcode
          email
          phone
          defaultAddress
          useForShipping
        }
      }
    }
  ''';

  /// Get available shipping rates.
  ///
  /// VERIFIED: `shippingMethods: ShippingMethods` (a Query, no arguments).
  /// `collectionShippingRates` does not exist on this schema.
  ///
  /// Normally the methods arrive with the `saveCheckoutAddresses` response;
  /// this standalone query is the fallback when that cache is cold.
  static const String getShippingRates = r'''
    query shippingMethods {
      shippingMethods {
        message
        shippingMethods {
          title
          methods {
            code
            label
            price
            formattedPrice
            basePrice
            formattedBasePrice
          }
        }
      }
    }
  ''';

  /// Get available payment methods.
  ///
  /// VERIFIED: `paymentMethods(input: PaymentMethodsInput!): PaymentMethods`
  /// where `PaymentMethodsInput { shippingMethod: String! }`.
  /// `collectionPaymentMethods` does not exist on this schema.
  static const String getPaymentMethods = r'''
    query paymentMethods($shippingMethod: String!) {
      paymentMethods(input: { shippingMethod: $shippingMethod }) {
        message
        paymentMethods {
          method
          methodTitle
          description
          sort
          image
        }
      }
    }
  ''';

  /// Get all available countries (for address form dropdowns)
  /// API: https://api-docs.bagisto.com/api/graphql-api/shop/queries/get-countries.html
  /// Fetch all countries.
  ///
  /// VERIFIED against Bagisto's `admin/configuration/country.graphql`:
  ///   countries: [Country!]        # a PLAIN LIST
  ///   type Country { id  code  name  states  translations }
  ///
  /// The previous query asked for
  /// `countries(first: 250) { edges { node { _id } } }` — a Relay-style
  /// connection. Neither the `first` argument, the `edges/node` wrapper, nor
  /// `_id` exist on this schema, so the server rejected the whole document.
  /// The error was then swallowed twice (by the empty catch in the bloc, and
  /// by `shouldLogCheckoutOperation` which deliberately hides getCountries
  /// logs), leaving the field permanently empty and un-tappable.
  static const String getCountries = r'''
    query countries {
      countries {
        id
        code
        name
        # `name` is the untranslated default (English). Bagisto keeps localized
        # names in a `translations` relation keyed by locale — the X-LOCALE
        # header does NOT translate this field. Fetch them and pick the one
        # matching the app locale (see BagistoCountry.fromJson).
        translations {
          locale
          name
        }
      }
    }
  ''';

  /// Get states/provinces for a specific country
  /// API: https://api-docs.bagisto.com/api/graphql-api/shop/queries/get-country-state.html
  /// Returns CountryStateCursorConnection — requires edges/node wrapper
  /// Fetch states for a country by numeric country ID.
  ///
  /// VERIFIED: the real query is `countrieStates` (note Bagisto's own spelling
  /// — it is NOT `countryStates`) and it takes a `FilterCountryStateInput`:
  ///   countrieStates(input: FilterCountryStateInput): [CountryState!]
  static const String getCountryStates = r'''
    query countrieStates($countryId: ID) {
      countrieStates(input: { countryId: $countryId }) {
        id
        code
        defaultName
        countryId
        countryCode
        # Same as countries: localized names live in `translations`.
        translations {
          locale
          defaultName
        }
      }
    }
  ''';

  /// Alternative query using country code
  /// Fetch states for a country by ISO country code.
  static const String getCountryStatesByCode = r'''
    query countrieStatesByCode($countryCode: String) {
      countrieStates(input: { countryCode: $countryCode }) {
        id
        code
        defaultName
        countryId
        countryCode
      }
    }
  ''';
}

class CheckoutMutations {
  /// Save checkout addresses (billing + optional shipping).
  ///
  /// VERIFIED against `shop/checkout/save_checkout_addresses.graphql`:
  ///   saveCheckoutAddresses(input: SaveShippingAddressInput!): ShippingMethodsResponse
  ///   input SaveShippingAddressInput { billing: CheckoutAddressInput, shipping: CheckoutAddressInput }
  ///
  /// There is NO `createCheckoutAddress` mutation and no
  /// `createCheckoutAddressInput` type — hence
  /// `Unknown type "createCheckoutAddressInput"`.
  ///
  /// Two important shape changes:
  ///  1. The input is NESTED (billing/shipping objects), not flat
  ///     (`billingFirstName`, ...). `address` is a LIST of strings.
  ///  2. The response ALREADY contains the shipping AND payment methods, so
  ///     no separate rates query is needed after this call.
  static const String createCheckoutAddress = r'''
    mutation saveCheckoutAddresses($billing: CheckoutAddressInput, $shipping: CheckoutAddressInput) {
      saveCheckoutAddresses(input: { billing: $billing, shipping: $shipping }) {
        message
        jumpToSection
        cart {
          id
        }
        shippingMethods {
          title
          methods {
            code
            label
            price
            formattedPrice
            basePrice
            formattedBasePrice
          }
        }
        paymentMethods {
          method
          methodTitle
          description
          sort
          image
        }
      }
    }
  ''';

  /// Save selected shipping method.
  ///
  /// VERIFIED: `saveShipping(input: saveShippingMethodInput!): ShippingResponse`
  /// where `saveShippingMethodInput { method: String! }`.
  static const String createCheckoutShippingMethod = r'''
    mutation saveShipping($method: String!) {
      saveShipping(input: { method: $method }) {
        message
        jumpToSection
        cart {
          id
        }
      }
    }
  ''';

  /// Save selected payment method.
  ///
  /// VERIFIED: `savePayment(input: savePaymentMethodInput!): PaymentResponse`
  /// where `savePaymentMethodInput { method: String! }`.
  static const String createCheckoutPaymentMethod = r'''
    mutation savePayment($method: String!) {
      savePayment(input: { method: $method }) {
        message
        jumpToSection
        cart {
          id
        }
      }
    }
  ''';

  /// Place order
  static const String createCheckoutOrder = r'''
    mutation placeOrder {
      placeOrder {
        success
        redirectUrl
        selectedMethod
        order {
          id
          incrementId
        }
      }
    }
  ''';

  /// Apply coupon code.
  ///
  /// VERIFIED: `applyCoupon(input: ApplyCouponInput!): CouponResponse`
  /// where `ApplyCouponInput { code: String! }` and the response is
  /// `{ success, message, cart }` — the updated totals come back on `cart`,
  /// NOT as flat `discountAmount`/`grandTotal` fields.
  static const String createApplyCoupon = r'''
    mutation applyCoupon($code: String!) {
      applyCoupon(input: { code: $code }) {
        success
        message
        cart {
          id
          grandTotal
          subTotal
          taxTotal
          discountAmount
          # Formatted strings live on a NESTED `formattedPrice` object —
          # there are no flat `formattedGrandTotal`-style fields on Cart.
          formattedPrice {
            grandTotal
            subTotal
            taxTotal
            discountAmount
          }
        }
      }
    }
  ''';

  /// Remove coupon code
  /// Remove the applied coupon.
  ///
  /// VERIFIED: `removeCoupon: CouponResponse` — it takes NO arguments.
  static const String createRemoveCoupon = r'''
    mutation removeCoupon {
      removeCoupon {
        success
        message
        cart {
          id
          grandTotal
          subTotal
          taxTotal
          discountAmount
          formattedPrice {
            grandTotal
            subTotal
            taxTotal
            discountAmount
          }
        }
      }
    }
  ''';
}
