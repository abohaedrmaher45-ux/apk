// GraphQL queries for Account Dashboard
// APIs: Customer Profile, Customer Addresses, Product Reviews
//
// Note: Orders and Wishlist queries are NOT available in the
// Bagisto demo storefront GraphQL schema. The dashboard gracefully
// shows empty states for those sections.

class AccountQueries {
  /// Get customer profile
  /// Actual API query: readCustomerProfile(id: ID!)
  /// Returns: CustomerProfile type
  static const String getCustomerProfile = r'''
    query accountInfo {
      accountInfo {
        id
        firstName
        lastName
        name
        email
        dateOfBirth
        gender
        phone
        status
        subscribedToNewsLetter
        isVerified
        image
        imageUrl
      }
    }
  ''';

  /// Get customer addresses (cursor-based pagination)
  /// Actual API query: getCustomerAddresses
  /// Returns: GetCustomerAddressesCursorConnection
  static const String getCustomerAddresses = r'''
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
          email
          companyName
          vatId
          address
          city
          state
          stateName
          country
          countryName
          postcode
          phone
          defaultAddress
          useForShipping
          createdAt
          updatedAt
        }
      }
    }
  ''';

  /// Get product reviews (cursor-based pagination)
  /// Actual API query: productReviews
  /// Returns: ProductReviewCursorConnection
  /// Note: Pass productId to fetch reviews for a specific product.
  static const String getProductReviews = r'''
    query productReviews($first: Int, $after: String, $productId: Int) {
      productReviews(first: $first, after: $after, product_id: $productId) {
        edges {
          node {
            id
            _id
            name
            title
            rating
            comment
            status
            createdAt
            updatedAt
          }
          cursor
        }
        pageInfo {
          hasNextPage
          endCursor
        }
        totalCount
      }
    }
  ''';

  /// Get customer reviews (cursor-based pagination) with product data.
  /// Bagisto API query: customerReviews(first: Int, after: String)
  /// Returns review with nested product (name, sku, type, images) for UI display.
  static const String getCustomerReviews = r'''
    query reviewsList {
      reviewsList(input: {}) {
        paginatorInfo {
          count
          currentPage
          lastPage
          total
        }
        data {
          id
          title
          rating
          comment
          status
          productId
          customerId
          createdAt
          updatedAt
          images {
            id
            path
            url
          }
          product {
            id
            type
            sku
            name
          }
          customer {
            id
            firstName
            lastName
            name
          }
        }
      }
    }
  ''';

  // ─── Address Mutations ───

  /// Set an address as the default.
  ///
  /// VERIFIED against `shop/customer/addresses.graphql`:
  ///   setDefaultAddress(id: ID!): AddressResponse
  ///
  /// This is a dedicated mutation taking ONLY the id — the old version sent the
  /// entire address through a `createAddUpdateCustomerAddress` mutation that
  /// does not exist on this schema.
  static const String setDefaultAddress = r'''
    mutation setDefaultAddress($id: ID!) {
      setDefaultAddress(id: $id) {
        success
        message
        address {
          id
          addressType
          firstName
          lastName
          email
          companyName
          vatId
          address
          city
          state
          stateName
          country
          countryName
          postcode
          phone
          defaultAddress
          useForShipping
        }
      }
    }
  ''';

  /// Delete a customer address.
  ///
  /// VERIFIED: `deleteAddress(id: ID!): StatusResponse`.
  /// There is no `createDeleteCustomerAddress` mutation.
  static const String deleteCustomerAddress = r'''
    mutation deleteAddress($id: ID!) {
      deleteAddress(id: $id) {
        success
        message
      }
    }
  ''';

  /// Add/update a customer address
  /// Discovered via schema introspection on api-demo.bagisto.com:
  ///   mutation: createAddUpdateCustomerAddress
  ///   input type: createAddUpdateCustomerAddressInput
  ///   Fields: addressId (Int, optional — omit for create),
  ///           firstName, lastName, email, phone, address1, address2,
  ///           country, state, city, postcode,
  ///           useForShipping (Boolean), defaultAddress (Boolean)
  /// Create a NEW customer address.
  ///
  /// VERIFIED: `createAddress(input: AddressInput!): AddressResponse`.
  ///
  /// There is no single create-or-update mutation on this schema — create and
  /// update are separate operations, and `updateAddress` takes the id as its
  /// own argument (NOT an `addressId` field inside the input).
  ///
  /// `AddressInput.address` is a LIST of strings, not `address1`/`address2`.
  /// `companyName` and `vatId` ARE supported (the old comment claimed they were
  /// not — that was true only of the invented input type).
  static const String createAddUpdateCustomerAddress = r'''
    mutation createAddress($input: AddressInput!) {
      createAddress(input: $input) {
        success
        message
        address {
          id
          addressType
          firstName
          lastName
          email
          companyName
          vatId
          address
          city
          state
          stateName
          country
          countryName
          postcode
          phone
          defaultAddress
          useForShipping
        }
      }
    }
  ''';

  /// Update an EXISTING customer address.
  ///
  /// VERIFIED: `updateAddress(id: ID!, input: AddressInput!): AddressResponse`.
  static const String updateCustomerAddress = r'''
    mutation updateAddress($id: ID!, $input: AddressInput!) {
      updateAddress(id: $id, input: $input) {
        success
        message
        address {
          id
          addressType
          firstName
          lastName
          email
          companyName
          vatId
          address
          city
          state
          stateName
          country
          countryName
          postcode
          phone
          defaultAddress
          useForShipping
        }
      }
    }
  ''';

  // ─── Profile Mutations ───

  /// Update customer profile
  /// Bagisto API mutation: updateCustomerProfile
  /// Input: firstName, lastName, phone, gender, dateOfBirth, subscribedToNewsLetter
  static const String updateCustomerProfile = r'''
    mutation updateAccount($input: UpdateCustomerInput!) {
      updateAccount(input: $input) {
        success
        message
        customer {
          id
          firstName
          lastName
          email
          phone
          gender
          dateOfBirth
          subscribedToNewsLetter
        }
      }
    }
  ''';

  /// Change customer email — requires current password for verification
  /// Bagisto API mutation: updateCustomerProfile with email + currentPassword
  static const String changeCustomerEmail = r'''
    mutation updateAccount($input: UpdateCustomerInput!) {
      updateAccount(input: $input) {
        success
        message
        customer {
          id
          email
        }
      }
    }
  ''';

  /// Change customer password — requires current + new password
  /// Bagisto API mutation: updateCustomerProfile with password fields
  static const String changeCustomerPassword = r'''
    mutation updateAccount($input: UpdateCustomerInput!) {
      updateAccount(input: $input) {
        success
        message
      }
    }
  ''';

  /// Delete customer account — requires current password for verification
  /// Bagisto API mutation: deleteCustomerAccount
  static const String deleteCustomerAccount = r'''
    mutation deleteAccount($password: String!) {
      deleteAccount(password: $password) {
        success
        message
      }
    }
  ''';

  /// Get available countries for the address form.
  ///
  /// VERIFIED against `admin/configuration/country.graphql`:
  ///   countries: [Country!]     # plain list — NOT a cursor connection
  ///
  /// The old doc-comment described a `CountryCursorConnection` with
  /// `edges/node/_id`; none of that exists on this schema.
  static const String getCountries = r'''
    query countries {
      countries {
        id
        code
        name
        # Localized names live in `translations` — the X-LOCALE header does not
        # translate `name`. Resolved against the app locale in the repository.
        translations {
          locale
          name
        }
      }
    }
  ''';

  /// Get states/provinces for a specific country.
  ///
  /// VERIFIED: the real query is `countrieStates` (Bagisto's own spelling) and
  /// it takes a `FilterCountryStateInput`, returning a plain list.
  static const String getCountryStates = r'''
    query countrieStates($countryId: ID) {
      countrieStates(input: { countryId: $countryId }) {
        id
        code
        defaultName
        countryId
        countryCode
        translations {
          locale
          defaultName
        }
      }
    }
  ''';

  // ─── Wishlist Queries & Mutations ───

  /// Get wishlists (cursor-paginated).
  /// Bagisto API: wishlists(first: Int, after: String)
  /// Returns: WishlistCursorConnection { edges { node { ... } }, pageInfo, totalCount }
  static const String getWishlists = r'''
    query wishlists($first: Int, $page: Int) {
      wishlists(first: $first, page: $page, input: {}) {
        paginatorInfo {
          count
          currentPage
          lastPage
          total
        }
        data {
          id
          productId
          customerId
          movedToCart
          createdAt
          updatedAt
          product {
            id
            sku
            type
            name
            urlKey
            price
            specialPrice
            shortDescription
            images {
              id
              url
              path
            }
            priceHtml {
              regularPrice
              formattedRegularPrice
              finalPrice
              formattedFinalPrice
            }
          }
          customer {
            id
          }
          channel {
            id
          }
        }
      }
    }
  ''';

  /// Remove a product from the wishlist.
  ///
  /// VERIFIED against `shop/customer/wishlist.graphql`:
  ///   removeFromWishlist(productId: ID!): WishlistResponse
  ///
  /// NOTE the key change: the real API removes by **productId**, not by the
  /// wishlist-row id the old `deleteWishlist` mutation tried to use.
  static const String deleteWishlist = r'''
    mutation removeFromWishlist($productId: ID!) {
      removeFromWishlist(productId: $productId) {
        success
        message
      }
    }
  ''';

  /// Move a wishlist item to cart.
  ///
  /// VERIFIED against `shop/customer/wishlist.graphql`:
  ///   moveToCart(id: ID!, quantity: Int!): WishlistResponse
  ///
  /// `id` here is the WISHLIST ROW id (not the product id).
  static const String moveWishlistToCart = r'''
    mutation moveToCart($id: ID!, $quantity: Int!) {
      moveToCart(id: $id, quantity: $quantity) {
        success
        message
      }
    }
  ''';

  // ──────────────────────────────────────────────
  // Compare Items
  // ──────────────────────────────────────────────

  /// Get compare items (cursor-paginated).
  /// Bagisto API query: compareItems(first: Int, after: String)
  /// Returns: CompareItemCursorConnection
  static const String getCompareItems = r'''
    query compareProducts($first: Int, $page: Int) {
      compareProducts(first: $first, page: $page, input: {}) {
        paginatorInfo {
          count
          currentPage
          lastPage
          total
        }
        data {
          id
          productId
          customerId
          createdAt
          updatedAt
          product {
            id
            sku
            type
            name
            description
            shortDescription
            urlKey
            priceHtml {
              regularPrice
              formattedRegularPrice
              finalPrice
              formattedFinalPrice
              currencyCode
            }
          }
          customer {
            id
            firstName
            lastName
            email
          }
        }
      }
    }
  ''';

  /// Delete a single compare item.
  /// Bagisto API mutation: deleteCompareItem(input: deleteCompareItemInput!)
  static const String deleteCompareItem = r'''
    mutation DeleteCompareItem($id: ID!) {
      deleteCompareItem(input: {id: $id}) {
        compareItem {
          id
          product {
            sku
            type
            createdAt
          }
        }
      }
    }
  ''';

  /// Delete all compare items.
  /// Bagisto API mutation: createDeleteAllCompareItems(input: {})
  static const String deleteAllCompareItems = r'''
    mutation createDeleteAllCompareItems {
      createDeleteAllCompareItems(input: {}) {
        deleteAllCompareItems {
          message
        }
      }
    }
  ''';

  // ──────────────────────────────────────────────
  // Create Wishlist
  // ──────────────────────────────────────────────

  /// Add product to wishlist.
  ///
  /// VERIFIED against Bagisto's `shop/customer/wishlist.graphql`:
  ///   addToWishlist(productId: ID!): WishlistResponse
  ///
  /// There is NO `createWishlist` mutation and NO `createWishlistInput` type —
  /// the old query invented both, so the server rejected the document before
  /// executing it ("Unknown type \"createWishlistInput\"") and nothing was ever
  /// added to the wishlist.
  ///
  /// `WishlistResponse.wishlist` returns the customer's FULL wishlist, so we
  /// read back `productId` to locate the row we just created.
  static const String createWishlist = r'''
    mutation addToWishlist($productId: ID!) {
      addToWishlist(productId: $productId) {
        success
        message
        wishlist {
          id
          productId
        }
      }
    }
  ''';

  // ──────────────────────────────────────────────
  // Create Compare Item
  // ──────────────────────────────────────────────

  /// Add product to compare list.
  /// Bagisto API mutation: createCompareItem(input: createCompareItemInput!)
  static const String createCompareItem = r'''
    mutation CreateCompareItem($input: createCompareItemInput!) {
      createCompareItem(input: $input) {
        compareItem {
          id
          _id
          createdAt
          updatedAt
          product {
            id
          }
          customer {
            id
          }
        }
      }
    }
  ''';

  // ──────────────────────────────────────────────
  // Customer Orders
  // ──────────────────────────────────────────────

  /// Get the customer's orders.
  ///
  /// VERIFIED: `ordersList(input: FilterCustomerOrderInput): [Order!]`
  /// with `@paginate(type: "PAGINATOR")` -> `{ paginatorInfo, data }`.
  ///
  /// `statusLabel` is the TRANSLATED status (resolved server-side via
  /// OrderQuery@getTranslatedOrderStatus). Display that, not the raw `status`
  /// code, so order states follow the app locale.
  static const String getCustomerOrders = r'''
    query ordersList($page: Int, $first: Int, $status: String) {
      ordersList(page: $page, first: $first, input: { status: $status }) {
        paginatorInfo {
          count
          currentPage
          lastPage
          total
        }
        data {
          id
          incrementId
          status
          statusLabel
          channelName
          customerEmail
          customerFirstName
          customerLastName
          totalItemCount
          totalQtyOrdered
          grandTotal
          baseGrandTotal
          subTotal
          taxAmount
          discountAmount
          shippingAmount
          shippingTitle
          couponCode
          orderCurrencyCode
          baseCurrencyCode
          createdAt
          updatedAt
        }
      }
    }
  ''';

  /// Get a single order's detail by ID.
  ///
  /// VERIFIED against `shop/customer/orders.graphql`:
  ///   orderDetail(id: ID!): Order
  ///
  /// There is NO `customerOrder` query — hence
  /// `Cannot query field "customerOrder" on type "Query"`.
  ///
  /// Shape notes (all verified against `type Order`):
  ///  - `items` and `addresses` are plain LISTS (@hasMany) — the old query
  ///    wrapped them in a Relay `edges { node { ... } }` connection that does
  ///    not exist here.
  ///  - There is no `_id` field anywhere; `id` is the identifier.
  ///  - `id` is an Int, and it is the plain numeric id — NOT an IRI string
  ///    like "/api/shop/customer-orders/1".
  ///  - `statusLabel` gives the TRANSLATED status text; `status` is the raw
  ///    code. The orders screen should display statusLabel.
  static const String getCustomerOrder = r'''
    query orderDetail($id: ID!) {
      orderDetail(id: $id) {
        id
        incrementId
        status
        statusLabel
        channelName
        customerEmail
        customerFirstName
        customerLastName
        shippingMethod
        shippingTitle
        couponCode
        totalItemCount
        totalQtyOrdered
        grandTotal
        baseGrandTotal
        grandTotalInvoiced
        grandTotalRefunded
        subTotal
        baseSubTotal
        taxAmount
        baseTaxAmount
        discountAmount
        baseDiscountAmount
        shippingAmount
        baseShippingAmount
        baseCurrencyCode
        channelCurrencyCode
        orderCurrencyCode
        createdAt
        updatedAt
        formattedPrice {
          grandTotal
          subTotal
          taxTotal
          discountAmount
          shippingAmount
        }
        payment {
          id
          method
          methodTitle
        }
        items {
          id
          sku
          name
          type
          additional
          price
          total
          qtyOrdered
          qtyShipped
          qtyInvoiced
          qtyCanceled
          qtyRefunded
          formattedPrice {
            price
            total
          }
        }
        billingAddress {
          id
          addressType
          firstName
          lastName
          companyName
          address
          city
          state
          stateName
          country
          countryName
          postcode
          email
          phone
          vatId
        }
        shippingAddress {
          id
          addressType
          firstName
          lastName
          companyName
          address
          city
          state
          stateName
          country
          countryName
          postcode
          email
          phone
          vatId
        }
      }
    }
  ''';

  // ──────────────────────────────────────────────
  // Create Product Review
  // ──────────────────────────────────────────────

  /// Create a product review.
  /// Bagisto API mutation: createProductReview(input: createProductReviewInput!)
  /// Required: productId, title, comment, rating, name
  /// Optional: email, status, attachments, clientMutationId
  static const String createProductReview = r'''
    mutation createReview($input: CreateReviewInput!) {
      createReview(input: $input) {
        success
        message
        review {
          id
          name
          title
          rating
          comment
          status
          createdAt
          updatedAt
        }
      }
    }
  ''';

  // ──────────────────────────────────────────────
  // Customer Invoices
  // ──────────────────────────────────────────────

  /// Get the customer's invoices.
  ///
  /// VERIFIED: `viewInvoices(input: OrderInvoiceInput): [Invoice!]`
  /// with `@paginate(type: "PAGINATOR")` -> `{ paginatorInfo, data }`.
  ///
  /// `customerInvoices` does not exist, nor does the Relay edges/node wrapper
  /// or the `_id` field the old query used.
  static const String getCustomerInvoices = r'''
    query viewInvoices($first: Int, $page: Int, $orderId: Int) {
      viewInvoices(first: $first, page: $page, input: { orderId: $orderId }) {
        paginatorInfo {
          count
          currentPage
          lastPage
          total
        }
        data {
          id
          incrementId
          state
          totalQty
          emailSent
          subTotal
          grandTotal
          baseGrandTotal
          shippingAmount
          taxAmount
          discountAmount
          orderCurrencyCode
          createdAt
          updatedAt
          order {
            id
            incrementId
          }
          items {
            id
            name
            sku
            qty
            price
            total
          }
        }
      }
    }
  ''';

  /// Get a single invoice by ID.
  ///
  /// VERIFIED: `viewInvoice(id: ID): Invoice`.
  static const String getCustomerInvoice = r'''
    query viewInvoice($id: ID!) {
      viewInvoice(id: $id) {
        id
        incrementId
        state
        totalQty
        emailSent
        subTotal
        grandTotal
        baseGrandTotal
        shippingAmount
        taxAmount
        discountAmount
        orderCurrencyCode
        createdAt
        updatedAt
        order {
          id
          incrementId
        }
        items {
          id
          name
          sku
          qty
          price
          total
        }
      }
    }
  ''';

  /// Reorder an existing order.
  ///
  /// VERIFIED: `reorder(id: ID!): CartItemResponse`.
  /// There is no `createReorderOrder` mutation and no `reorderOrder` payload —
  /// the response is the standard `{ success, message, cart }`.
  static const String reorderOrder = r'''
    mutation reorder($id: ID!) {
      reorder(id: $id) {
        success
        message
        cart {
          id
          itemsCount
        }
      }
    }
  ''';

  /// Cancel an order.
  ///
  /// VERIFIED: `cancelCustomerOrder(id: ID!): CancelOrderResponse`.
  static const String cancelCustomerOrder = r'''
    mutation cancelCustomerOrder($id: ID!) {
      cancelCustomerOrder(id: $id) {
        success
        message
      }
    }
  ''';

  // ──────────────────────────────────────────────
  // Customer Shipments
  // ──────────────────────────────────────────────

  /// Get shipments for an order.
  ///
  /// VERIFIED: `viewShipments(input: OrderShipmentInput): [Shipment!]`
  /// with `@paginate(type: "PAGINATOR")` -> `{ paginatorInfo, data }`.
  static const String getCustomerOrderShipments = r'''
    query viewShipments($first: Int, $page: Int, $orderId: Int) {
      viewShipments(first: $first, page: $page, input: { orderId: $orderId }) {
        paginatorInfo {
          count
          currentPage
          lastPage
          total
        }
        data {
          id
          status
          totalQty
          carrierCode
          carrierTitle
          trackNumber
          inventorySourceName
          createdAt
          updatedAt
          items {
            id
            name
            sku
            qty
          }
        }
      }
    }
  ''';

  /// Get a single shipment by ID.
  ///
  /// VERIFIED: `viewShipment(id: ID): Shipment`.
  /// Note: `Shipment` has NO `shippingNumber` or `_id` field — the old query
  /// invented both. The tracking field is `trackNumber`.
  static const String getCustomerOrderShipment = r'''
    query viewShipment($id: ID!) {
      viewShipment(id: $id) {
        id
        status
        totalQty
        totalWeight
        carrierCode
        carrierTitle
        trackNumber
        inventorySourceName
        createdAt
        updatedAt
        order {
          id
          incrementId
        }
        items {
          id
          name
          sku
          qty
        }
      }
    }
  ''';

  /// Get available locales for language selection
  /// Actual API query: locales
  /// Returns: LocalesCursorConnection with available languages/locales
  static const String getLocales = r'''
    query getLocales {
      locales {
        edges {
          node {
            id
            _id
            code
            name
            direction
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  ''';

  /// Get available currencies for currency selection
  static const String getCurrencies = r'''
    query allCurrency {
      currencies {
        edges {
          node {
            id
            _id
            code
            name
            symbol
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  ''';

  /// Get customer downloadable products (cursor-based pagination)
  /// Bagisto API query: customerDownloadableProducts(first: Int, after: String)
  /// Returns: DownloadableProductCursorConnection with product details
  static const String getCustomerDownloadableProducts = r'''
    query downloadableLinkPurchases($first: Int, $page: Int) {
      downloadableLinkPurchases(first: $first, page: $page, input: {}) {
        paginatorInfo {
          count
          currentPage
          lastPage
          total
        }
        data {
          id
          productName
          name
          url
          file
          fileName
          type
          downloadBought
          downloadUsed
          status
          orderId
          orderItemId
          createdAt
          updatedAt
          order {
            id
            incrementId
            status
          }
        }
      }
    }
  ''';

  /// Get CMS pages list
  /// Bagisto API query: pages
  /// Returns: PagesCursorConnection with page details including translations
  static const String getCmsPages = r'''
    query getCmsPages {
      pages {
        edges {
          node {
            id
            _id
            layout
            createdAt
            updatedAt
            translation {
              id
              _id
              pageTitle
              urlKey
              htmlContent
              metaTitle
              metaDescription
              metaKeywords
              locale
            }
          }
        }
      }
    }
  ''';

  /// Create contact us submission
  /// Bagisto API mutation: createContactUs
  /// Returns: ContactUsResponse with success and message
  static const String createContactUs = r'''
    mutation contactUs($input: ContactUsInput!) {
      contactUs(input: $input) {
        success
        message
      }
    }
  ''';
}
