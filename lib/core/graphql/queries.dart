/// GraphQL queries for the Bagisto category & catalog API
/// Ported from: nextjs-commerce-main/src/graphql/catelog/
library;

class StoreConfigQueries {
  /// Fetches the configured Bagisto channel with its locales, currencies,
  /// and defaults used during app startup.
  static const String getChannelById = r'''
    query getChannelByID($id: ID!) {
      channel(id: $id) {
        id
        code
        hostname
        theme
        timezone
        homeSeo
        logoUrl
        faviconUrl
        locales {
          id
          code
          name
          direction
        }
        currencies {
          id
          code
          name
          symbol
        }
        defaultLocale {
          id
          code
          name
          direction
        }
        baseCurrency {
          id
          code
          name
          symbol
        }
      }
    }
  ''';
}

class CategoryQueries {
  /// GET_TREE_CATEGORIES – fetches hierarchical category tree
  /// Source: nextjs-commerce/src/graphql/catelog/queries/Category.ts
  static const String getTreeCategories = r'''
    query homeCategories($parentId: String) {
      homeCategories(
        getCategoryTree: false
        input: [
          { key: "status", value: "1" }
          { key: "parent_id", value: $parentId }
        ]
      ) {
        id
        position
        logoPath
        logoUrl
        bannerPath
        bannerUrl
        status
        parentId
        name
        slug
        urlPath
        description
        metaTitle
        children {
          id
          position
          logoPath
          logoUrl
          bannerPath
          bannerUrl
          status
          parentId
          name
          slug
          urlPath
        }
      }
    }
  ''';

  /// GET_HOME_CATEGORIES – flat list with logo
  /// Source: nextjs-commerce/src/graphql/catelog/queries/HomeCategories.ts
  static const String getHomeCategories = r'''
    query homeCategories {
      homeCategories(
        getCategoryTree: false
        input: [
          { key: "status", value: "1" }
          { key: "parent_id", value: "1" }
        ]
      ) {
        id
        position
        logoUrl
        logoPath
        bannerUrl
        status
        parentId
        name
        slug
        urlPath
      }
    }
  ''';
}

class ProductQueries {
  /// Product core fragment fields
  static const String _productCoreFragment = r'''
    fragment ProductCore on Product {
      id
      sku
      type
      name
      urlKey
      price
      specialPrice
      isSaleable
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
        currencyCode
      }
      reviews {
        id
        name
        title
        rating
        comment
      }
    }
  ''';

  /// Product section fragment (lightweight)
  /// مطابق تمامًا لاستعلام الشاشة الرئيسية العامل في Postman
  /// (Shop/Common/All Product List) لتفادي أي خطأ داخلي.
  static const String _productSectionFragment = r'''
    fragment ProductSection on Product {
      id
      productNumber
      sku
      type
      name
      urlKey
      price
      specialPrice
      shortDescription
      description
      images {
        id
        type
        path
        url
        productId
      }
      # priceHtml carries the backend-formatted price WITH the currency symbol
      # (e.g. "٤٥٫٠٠ €"). Home & category cards must use these formatted fields
      # instead of the bare numeric `price`, otherwise no € symbol is shown.
      priceHtml {
        regularPrice
        formattedRegularPrice
        finalPrice
        formattedFinalPrice
        currencyCode
      }
      weight
      # Custom select attributes (color / size / brand …) come back here as a
      # flat list: { code, label, value }. The product detail page reads color,
      # size and brand from this. Without it they never render.
      additionalData {
        id
        code
        label
        value
        admin_name
        type
      }
    }
  ''';

  /// Product detailed common fragment (shared by all product types)
  static const String _productDetailedCommonFragment = r'''
    fragment ProductDetailedCommon on Product {
      id
      sku
      type
      name
      urlKey
      description
      shortDescription
      price
      specialPrice
      isSaleable
      guestCheckout
      images {
        id
        path
        type
      }
      reviews {
        rating
        id
        name
        title
        comment
        createdAt
      }
      relatedProducts {
        id
        sku
        name
        urlKey
        type
        price
        specialPrice
        isSaleable
      }
    }
  ''';

  static const String _configurableDetailedFields = r'''
      superAttributeOptions
      combinations
      attributeValues {
        textValue
        booleanValue
        integerValue
        floatValue
        dateValue
        attribute {
          code
          adminName
        }
      }
      variants {
        id
        name
        sku
        price
        specialPrice
        attributeValues {
          textValue
          booleanValue
          integerValue
          floatValue
          dateValue
          attribute {
            code
            adminName
          }
        }
      }
      categories {
        id
        name
      }
  ''';

  static const String _downloadableDetailedFields = r'''
      downloadableLinks {
        id
        type
        price
        formattedPrice
        downloads
        sortOrder
        fileUrl
        sampleFileUrl
        translations {
          title
        }
      }
      downloadableSamples {
        id
        type
        fileUrl
        sortOrder
        translations {
          title
        }
      }
  ''';

  static const String _groupedDetailedFields = r'''
      groupedProducts {
        id
        qty
        sortOrder
        associatedProduct {
          id
          name
          sku
          price
          specialPrice
          images {
            id
          }
        }
      }
  ''';

  static const String _bundleDetailedFields = r'''
      bundleOptions {
        id
        type
        isRequired
        sortOrder
        translations {
          label
        }
        bundleOptionProducts {
          id
          qty
          isDefault
          isUserDefined
          sortOrder
          product {
            id
            name
            sku
            price
            images {
              id
            }
          }
        }
      }
  ''';

  static const String _bookingDetailedFields = r'''
  ''';

  static String _typeSpecificDetailedFields(String? productType) {
    final normalized = (productType ?? '').toLowerCase().trim();
    switch (normalized) {
      case 'simple':
      case 'virtual':
        return '';
      case 'configurable':
      case 'variable':
        return _configurableDetailedFields;
      case 'downloadable':
        return _downloadableDetailedFields;
      case 'grouped':
        return _groupedDetailedFields;
      case 'bundle':
        return _bundleDetailedFields;
      case 'booking':
        return _bookingDetailedFields;
      default:
        // Unknown type: request only the safe, universally-available
        // fields. Combining ALL type fragments here (including
        // downloadableLinks/downloadableSamples, which expose direct
        // file URLs) causes the API to reject the whole request with
        // "Unauthenticated" for guest/unauthenticated sessions.
        // configurable + grouped + bundle are metadata-only and safe;
        // downloadable + booking are excluded from the fallback.
        return _configurableDetailedFields +
            _groupedDetailedFields +
            _bundleDetailedFields;
    }
  }

  /// Type-optimized product detail query by URL key.
  static String getProductByUrlKeyByType(String? productType) {
    final normalized = (productType ?? '').toLowerCase().trim();
    if (normalized == 'booking') {
      return getBookingProductByUrlKeyForType('default');
    }

    final typeFields = _typeSpecificDetailedFields(productType);
    return '''
    $_productDetailedCommonFragment

    query GetProductByUrlKey(\$urlKey: String!) {
      product(urlKey: \$urlKey) {
        ...ProductDetailedCommon
        $typeFields
      }
    }
  ''';
  }

  static const String _bookingProductCoreFields = r'''
      id
      sku
      type
      name
      urlKey
      description
      shortDescription
      price
      specialPrice
      isSaleable
      images {
        id
        path
        type
      }
  ''';

  static const String _bookingTypeProbeFields = r'''
      bookingProducts {
        id
        type
      }
  ''';

  static const String _bookingCommonNodeFields = r'''
            id
            type
            qty
            location
            showLocation
            availableFrom
            availableTo
  ''';

  static String _bookingSlotFieldsForType(String bookingType) {
    switch (bookingType.toLowerCase().trim()) {
      case 'appointment':
        return r'''
            appointmentSlot {
              id
              bookingProductId
              duration
              breakTime
              sameSlotAllDays
              slots
            }
        ''';
      case 'rental':
        return r'''
            rentalSlot {
              id
              bookingProductId
              rentingType
              dailyPrice
              hourlyPrice
              sameSlotAllDays
              slots
            }
        ''';
      case 'table':
        return r'''
            tableSlot {
              id
              bookingProductId
              priceType
              guestLimit
              duration
              breakTime
              preventSchedulingBefore
              sameSlotAllDays
              slots
            }
        ''';
      case 'event':
        return r'''
            eventTickets {
              id
              bookingProductId
              price
              formattedPrice
              qty
              specialPrice
              formattedSpecialPrice
              specialPriceFrom
              specialPriceTo
              translations {
                locale
                name
                description
              }
            }
        ''';
      case 'default':
      default:
        return r'''
            defaultSlot {
              id
              bookingType
              duration
              breakTime
              slots
            }
        ''';
    }
  }

  static String getBookingProductTypeByUrlKey =
      '''
    query GetBookingProductTypeByUrlKey(\$urlKey: String!) {
      product(urlKey: \$urlKey) {
$_bookingTypeProbeFields
      }
    }
  ''';

  static String getBookingProductTypeById =
      '''
    query GetBookingProductTypeById(\$id: ID!) {
      product(id: \$id) {
$_bookingTypeProbeFields
      }
    }
  ''';

  static String getBookingProductByUrlKeyForType(String bookingType) {
    final slotFields = _bookingSlotFieldsForType(bookingType);
    return '''
    query GetBookingProductByUrlKeyForType(\$urlKey: String!) {
      product(urlKey: \$urlKey) {
$_bookingProductCoreFields
        bookingProducts {
          $_bookingCommonNodeFields
          $slotFields
        }
      }
    }
  ''';
  }

  static String getBookingProductByIdForType(String bookingType) {
    final slotFields = _bookingSlotFieldsForType(bookingType);
    return '''
    query GetBookingProductByIdForType(\$id: ID!) {
      product(id: \$id) {
$_bookingProductCoreFields
        bookingProducts {
          $_bookingCommonNodeFields
          $slotFields
        }
      }
    }
  ''';
  }

  static const String getBookingSlots = r'''
    query GetBookingSlots(
      $id: Int!
      $date: String!
    ) {
      bookingSlots(id: $id, date: $date) {
        slotId
        from
        to
        timestamp
        qty
      }
    }
  ''';

  static const String getBookingRentalHourlySlots = r'''
    query GetBookingSlotsSummary(
      $id: Int!
      $date: String!
    ) {
      bookingSlots(id: $id, date: $date) {
        slotId
        time
        slots
      }
    }
  ''';

  /// Product detailed fragment
  static const String _productDetailedFragment = r'''
    fragment ProductDetailed on Product {
      id
      sku
      type
      name
      urlKey
      description
      shortDescription
      price
      specialPrice
      weight
      isSaleable
      guestCheckout
      # Formatted price with the backend currency symbol (€).
      priceHtml {
        regularPrice
        formattedRegularPrice
        finalPrice
        formattedFinalPrice
        currencyCode
      }
      # Custom attributes (brand, weight/volume, etc.) exposed as a flat list.
      additionalData {
        id
        code
        label
        value
        admin_name
        type
      }
      images {
        id
        path
        type
      }
      attributeValues {
        textValue
        booleanValue
        integerValue
        floatValue
        dateValue
        attribute {
          code
          adminName
        }
      }
      variants {
        id
        name
        sku
        price
        specialPrice
        attributeValues {
          textValue
          booleanValue
          integerValue
          floatValue
          dateValue
          attribute {
            code
            adminName
          }
        }
      }
      categories {
        id
        name
      }
      reviews {
        rating
        id
        name
        title
        comment
        createdAt
      }
      relatedProducts {
        id
        sku
        name
        urlKey
        type
        price
        specialPrice
        isSaleable
      }
      downloadableLinks {
        id
        type
        price
        downloads
        sortOrder
        fileUrl
        sampleFileUrl
        translations {
          title
        }
      }
      downloadableSamples {
        id
        type
        fileUrl
        sortOrder
        translations {
          title
        }
      }
      groupedProducts {
        id
        qty
        sortOrder
        associatedProduct {
          id
          name
          sku
          price
          specialPrice
          images {
            id
          }
        }
      }
      bundleOptions {
        id
        type
        isRequired
        sortOrder
        translations {
          label
        }
        bundleOptionProducts {
          id
          qty
          isDefault
          isUserDefined
          sortOrder
          product {
            id
            name
            sku
            price
            images {
              id
            }
          }
        }
      }
    }
  ''';

  /// GET_PRODUCTS – paginated products with filtering/sorting
  /// Source: nextjs-commerce/src/graphql/catelog/queries/Product.ts
  /// Builds an `allProducts` query with an inline `input` list.
  ///
  /// The real Bagisto storefront exposes `allProducts(input: [{key,value}])`
  /// returning `{ paginatorInfo, data[] }`. It does NOT support cursor-style
  /// `products(first, after, filter, sortKey, ...)` arguments. [inputEntries]
  /// is a pre-rendered GraphQL list literal built by the repository, e.g.
  /// `{ key: "page", value: "1" }, { key: "limit", value: "20" }`.
  static String buildAllProductsQuery(String inputEntries) =>
      '''
    $_productSectionFragment

    query allProducts {
      allProducts(input: [ INPUT_ENTRIES ]) {
        paginatorInfo {
          count
          currentPage
          lastPage
          total
        }
        data {
          ...ProductSection
        }
      }
    }
  '''
          .replaceAll('INPUT_ENTRIES', inputEntries);

  /// Kept for backward-compatible references; both build `allProducts`.
  static String get getProducts =>
      buildAllProductsQuery('{ key: "limit", value: "20" }');
  static String get getFilterProducts =>
      buildAllProductsQuery('{ key: "limit", value: "20" }');

  /// GET_PRODUCT_BY_URL_KEY – single product detail
  /// Source: nextjs-commerce/src/graphql/catelog/queries/Product.ts
  static String getProductByUrlKey =
      '''
    $_productDetailedFragment

    query GetProductById(\$urlKey: String!) {
      product(urlKey: \$urlKey) {
        ...ProductDetailed
      }
    }
  ''';

  /// GET_RELATED_PRODUCTS
  /// Source: nextjs-commerce/src/graphql/catelog/queries/Product.ts
  static String getRelatedProducts =
      '''
    $_productSectionFragment

    query GetRelatedProducts(\$urlKey: String, \$first: Int) {
      product(urlKey: \$urlKey) {
        id
        sku
        relatedProducts(first: \$first) {
          ...ProductSection
        }
      }
    }
  ''';

  /// GET_PRODUCT_BY_ID – single product detail by numeric id
  /// Single product detail via the storefront `allProducts` query.
  /// The backend's `product(id:)` sits behind the admin-api guard, so we
  /// fetch the product through `allProducts(input:[{key:"id",...}])`, which
  /// works with a customer token, and read the first element of `data`.
  static String getProductById = '''
    query GetProductDetailById(\$id: String!) {
      allProducts(input: [{ key: "id", value: \$id }]) {
        data {
          id
          productNumber
          sku
          type
          name
          urlKey
          price
          specialPrice
          shortDescription
          description
          isSaleable
          guestCheckout
          createdAt
          updatedAt
          images {
            id
            type
            path
            url
          }
          additionalData {
            id
            code
            label
            value
            admin_name
            type
          }
          superAttributes {
            id
            code
            adminName
          }
          reviews {
            id
            name
            title
            rating
            comment
          }
        }
      }
    }
  ''';
}

class ThemeQueries {
  /// GET_THEME_CUSTOMIZATION
  /// Source: nextjs-commerce/src/graphql/theme/queries/ThemeCustomization.ts
  static const String getThemeCustomization = r'''
    query themeCustomization {
      themeCustomization {
        id
        themeCode
        type
        name
        sortOrder
        status
        channelId
        translations {
          id
          themeCustomizationId
          localeCode
          options {
            title
            css
            html
            links {
              url
              slug
              type
              id
            }
            images {
              title
              image
              imageUrl
              link
              banner_type
              category_id
              subtitle
              button_text
              start_date
              end_date
              sort_order
              status
            }
            column_1 {
              url
              title
              sortOrder
            }
            column_2 {
              url
              title
              sortOrder
            }
            column_3 {
              url
              title
              sortOrder
            }
            services {
              title
              description
              serviceIcon
            }
          }
        }
      }
    }
  ''';
}

/// Cart GraphQL mutations — CORRECTED to match the WORKING Bagisto schema.
/// Verified against GraphQL-API.postman_collection.json (Shop → Cart / Checkout).
///
/// The previous version used invented operations that DO NOT EXIST on the
/// server (createAddProductInCart / createReadCart / createUpdateCartItem …),
/// so every request failed with:
///   "Cannot query field \"createAddProductInCart\" on type \"Mutation\"".
///
/// Correct operations:
///   mutation addItemToCart(input:{ productId, quantity, ... }) { success message cart{...} }
///   query    cartDetail { ... }
///   query    cartItems  { ... }
///   mutation updateItemToCart(input:{ qty:[{cartItemId,quantity}] }) { ... }
///   mutation removeItemFromCart(input:{ cartItemId }) { ... }
///   mutation removeAllCartItem { success message }
///   mutation applyCoupon(input:{ code }) { ... }
///   mutation removeCoupon { ... }
class CartMutations {
  /// Create a guest cart token (session UUID) used as the Bearer token
  /// for subsequent guest cart calls.
  static const String createCartToken = r'''
    mutation CreateCart {
      createCartToken(input: {}) {
        cartToken {
          id
          cartToken
          customerId
          success
          message
          sessionToken
          isGuest
        }
      }
    }
  ''';

  /// Shared cart field selection — mirrors the Postman `cart { … }` block.
  static const String _cartFields = r'''
      id
      customerEmail
      customerFirstName
      customerLastName
      shippingMethod
      couponCode
      isGift
      itemsCount
      itemsQty
      globalCurrencyCode
      baseCurrencyCode
      channelCurrencyCode
      cartCurrencyCode
      grandTotal
      baseGrandTotal
      subTotal
      baseSubTotal
      taxTotal
      baseTaxTotal
      discountAmount
      baseDiscountAmount
      shippingAmount
      baseShippingAmount
      subTotalInclTax
      baseSubTotalInclTax
      checkoutMethod
      isGuest
      isActive
      customerId
      channelId
      createdAt
      updatedAt
      formattedPrice {
        grandTotal
        baseGrandTotal
        subTotal
        baseSubTotal
        taxTotal
        baseTaxTotal
        # NOTE: these are `discountAmount` / `baseDiscountAmount` on this
        # schema — NOT `discount` / `baseDiscount`. Using the wrong names made
        # the backend throw a 500 with an EMPTY graphqlErrors list, which is
        # why the cart was permanently empty. Verified against the working
        # Postman `cartDetail` response.
        discountAmount
        baseDiscountAmount
        discountedSubTotal
        baseDiscountedSubTotal
        shippingAmount
        baseShippingAmount
        subTotalInclTax
        baseSubTotalInclTax
      }
      items {
        id
        quantity
        sku
        type
        name
        couponCode
        weight
        totalWeight
        price
        basePrice
        total
        baseTotal
        taxPercent
        taxAmount
        discountPercent
        discountAmount
        priceInclTax
        totalInclTax
        parentId
        productId
        cartId
        additional
        createdAt
        updatedAt
        formattedPrice {
          price
          total
          taxAmount
          discountAmount
          priceInclTax
          totalInclTax
        }
        # Product images for the cart / checkout rows.
        #
        # The `product` relation used to be omitted here because requesting it
        # returned a 500. That 500 came from the customer never being resolved
        # (see CartMutationOverride), NOT from this relation. `images` is the
        # exact same selection the HOME screen uses successfully, so the cart
        # now renders images the same way instead of showing a placeholder.
        product {
          id
          images {
            id
            url
            path
          }
        }
      }
  ''';

  /// ADD_SIMPLE_PRODUCT_TO_CART
  static const String addSimpleProductToCart =
      r'''
    mutation addItemToCart($productId: ID!, $quantity: Int!) {
      addItemToCart(input: { productId: $productId, quantity: $quantity }) {
        success
        message
        cart {
''' +
      _cartFields +
      r'''
        }
      }
    }
  ''';

  /// ADD_CONFIGURABLE_PRODUCT_TO_CART
  static const String addConfigurableProductToCart =
      r'''
    mutation addItemToCart(
      $productId: ID!
      $quantity: Int!
      $selectedConfigurableOption: Int
      $superAttribute: [SuperAttributeInput]
    ) {
      addItemToCart(input: {
        productId: $productId
        quantity: $quantity
        selectedConfigurableOption: $selectedConfigurableOption
        superAttribute: $superAttribute
      }) {
        success
        message
        cart {
''' +
      _cartFields +
      r'''
        }
      }
    }
  ''';

  /// ADD_DOWNLOADABLE_PRODUCT_TO_CART
  static const String addDownloadableProductToCart =
      r'''
    mutation addItemToCart($productId: ID!, $quantity: Int!, $links: [Int]) {
      addItemToCart(input: { productId: $productId, quantity: $quantity, links: $links }) {
        success
        message
        cart {
''' +
      _cartFields +
      r'''
        }
      }
    }
  ''';

  /// ADD_GROUPED_PRODUCT_TO_CART
  static const String addGroupedProductToCart =
      r'''
    mutation addItemToCart($productId: ID!, $quantity: Int!, $qty: [QtyInput]) {
      addItemToCart(input: { productId: $productId, quantity: $quantity, qty: $qty }) {
        success
        message
        cart {
''' +
      _cartFields +
      r'''
        }
      }
    }
  ''';

  /// ADD_BUNDLE_PRODUCT_TO_CART
  static const String addBundleProductToCart =
      r'''
    mutation addItemToCart(
      $productId: ID!
      $quantity: Int!
      $bundleOptions: [BundleOptionInput]
    ) {
      addItemToCart(input: {
        productId: $productId
        quantity: $quantity
        bundleOptions: $bundleOptions
      }) {
        success
        message
        cart {
''' +
      _cartFields +
      r'''
        }
      }
    }
  ''';

  /// ADD_BOOKING_PRODUCT_TO_CART
  static const String addBookingProductToCart =
      r'''
    mutation addItemToCart(
      $productId: ID!
      $quantity: Int!
      $booking: BookingInput
    ) {
      addItemToCart(input: {
        productId: $productId
        quantity: $quantity
        booking: $booking
      }) {
        success
        message
        cart {
''' +
      _cartFields +
      r'''
        }
      }
    }
  ''';

  /// Back-compat alias.
  static const String addProductToCart = addSimpleProductToCart;

  /// READ CART — `cartDetail` is a QUERY (use client.query, not mutate).
  static const String getCart =
      r'''
    query cartDetail {
      cartDetail {
''' +
      _cartFields +
      r'''
      }
    }
  ''';

  /// CART_ITEMS — lightweight item-only query.
  static const String getCartItems = r'''
    query cartItems {
      cartItems {
        id
        quantity
        sku
        type
        name
        price
        total
        productId
        cartId
        formattedPrice {
          price
          total
        }
      }
    }
  ''';

  /// UPDATE_CART_ITEM — qty map keyed by cart item id.
  static const String updateCartItem =
      r'''
    mutation updateItemToCart($qty: [UpdateItemsQty!]) {
      updateItemToCart(input: { qty: $qty }) {
        success
        message
        cart {
''' +
      _cartFields +
      r'''
        }
      }
    }
  ''';

  /// REMOVE_CART_ITEM
  static const String removeCartItem =
      r'''
    mutation removeCartItem($cartItemId: ID!) {
      removeCartItem(id: $cartItemId) {
        success
        message
        cart {
''' +
      _cartFields +
      r'''
        }
      }
    }
  ''';

  /// REMOVE_ALL_ITEMS
  static const String removeAllCartItems = r'''
    mutation removeAllCartItem {
      removeAllCartItem {
        success
        message
      }
    }
  ''';

  /// APPLY_COUPON
  static const String applyCoupon =
      r'''
    mutation applyCoupon($code: String!) {
      applyCoupon(input: { code: $code }) {
        success
        message
        cart {
''' +
      _cartFields +
      r'''
        }
      }
    }
  ''';

  /// REMOVE_COUPON
  static const String removeCoupon =
      r'''
    mutation removeCoupon {
      removeCoupon {
        success
        message
        cart {
''' +
      _cartFields +
      r'''
        }
      }
    }
  ''';

  /// MERGE_CART — merge a guest cart into the logged-in user's cart after login.
  /// NOTE: verify this operation name against your Postman collection. If your
  /// Bagisto instance has no `createMergeCart`, remove this call and rely on the
  /// access token (the server associates the existing cart on first authed call).
  static const String mergeCart = r'''
    mutation createMergeCart($cartId: Int!) {
      createMergeCart(input: { cartId: $cartId }) {
        mergeCart {
          id
          cartToken
          taxAmount
          formattedTaxAmount
          subtotal
          formattedSubtotal
          shippingAmount
          formattedShippingAmount
          grandTotal
          formattedGrandTotal
          discountAmount
          formattedDiscountAmount
          couponCode
          itemsQty
          itemsCount
          isGuest
          items {
            id
            cartId
            productId
            name
            price
            formattedPrice
            total
            formattedTotal
            sku
            quantity
            type
            productUrlKey
            canChangeQty
          }
          success
          message
          sessionToken
        }
      }
    }
  ''';
}

class FilterQueries {
  /// GET_FILTER_OPTIONS (legacy – single attribute by ID)
  /// Source: nextjs-commerce/src/graphql/catelog/queries/ProductFilter.ts
  static const String getFilterOptions = r'''
    query FetchAttribute($id: ID!) {
      attribute(id: $id) {
        id
        code
        options {
          id
          adminName
          translations {
            id
            label
            locale
          }
        }
      }
    }
  ''';

  /// CATEGORY_ATTRIBUTE_FILTERS – dynamic filters per category
  /// Returns all filterable attributes for a given category slug,
  /// including price range, swatch info, and translated option labels.
  static const String getCategoryAttributeFilters = r'''
    query CategoryAttributeFilter($categorySlug: String, $first: Int) {
      categoryAttributeFilters(categorySlug: $categorySlug, first: $first) {
        id
        code
        adminName
        type
        swatchType
        validation
        position
        isRequired
        isUnique
        isFilterable
        isComparable
        isConfigurable
        isUserDefined
        isVisibleOnFront
        valuePerLocale
        valuePerChannel
        defaultValue
        maxPrice
        minPrice
        validations
        translations {
          id
          attributeId
          locale
          name
        }
        options {
          id
          adminName
          sortOrder
          swatchValue
          swatchValueUrl
          translations {
            id
            attributeOptionId
            locale
            label
          }
          translations {
            id
            attributeOptionId
            locale
            label
          }
        }
      }
    }
  ''';
}
