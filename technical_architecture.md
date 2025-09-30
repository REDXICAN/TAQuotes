# TurboAir Quotes - Technical Architecture Diagram

## Complete Technical Implementation Details

```mermaid
graph TB
    subgraph "🔧 FRONTEND - Technical Architecture"
        subgraph "🏗️ UI WIDGET TREE"
            subgraph "Authentication Widgets"
                T_Login[🔐 LoginScreen Widget<br/>━━━━━<br/>class LoginScreen extends ConsumerStatefulWidget<br/>TextFormField validators EmailValidator<br/>FirebaseAuth signInWithEmailAndPassword<br/>JWT token storage SecureStorage<br/>Session duration 30 days<br/>Error handling FirebaseAuthException]

                T_Register[📝 RegisterScreen Widget<br/>━━━━━<br/>class RegisterScreen extends ConsumerStatefulWidget<br/>Form key GlobalKey FormState<br/>FirebaseAuth createUserWithEmailAndPassword<br/>Database ref users uid set<br/>Email verification sendEmailVerification<br/>Password strength RegExp validation]

                T_ForgotPwd[🔑 ForgotPasswordScreen<br/>━━━━━<br/>class ForgotPasswordScreen extends StatelessWidget<br/>Email regex validation<br/>FirebaseAuth sendPasswordResetEmail<br/>Rate limited requests<br/>Error handling<br/>Success feedback]
            end

            subgraph "Main Application Widgets"
                T_Home[🏠 HomeScreen Widget<br/>━━━━━<br/>class HomeScreen extends ConsumerWidget<br/>ref watch totalProductsProvider AsyncValue int<br/>ref watch totalClientsProvider AsyncValue int<br/>ref watch totalQuotesProvider AsyncValue int<br/>ref watch cartItemCountProvider int<br/>GridView builder AspectRatio 1.5<br/>Hero animations tag product id]

                T_Products[📦 ProductsScreen Widget<br/>━━━━━<br/>class ProductsScreen extends ConsumerStatefulWidget<br/>ref watch productsProvider StreamProvider autoDispose<br/>ListView builder ScrollController<br/>Pagination initialLoad 24 loadMore 12<br/>CachedNetworkImage maxHeight 300 maxWidth 300<br/>Search Debouncer milliseconds 500<br/>Filter FilterChip widgets array]

                T_ProductDetail[🔍 ProductDetailScreen<br/>━━━━━<br/>class ProductDetailScreen extends ConsumerWidget<br/>PageView builder<br/>PhotoViewGallery<br/>Hero transition animations<br/>Stock by warehouse widget<br/>Add to cart functionality]

                T_Cart[🛒 CartScreen Widget<br/>━━━━━<br/>class CartScreen extends ConsumerStatefulWidget<br/>ref watch cartItemsProvider List CartItem<br/>Dismissible onDismissed removes item<br/>TextEditingController discountController<br/>Calculations subtotal qty times price<br/>tax subtotal times 0.08<br/>discount value or percent<br/>total subtotal plus tax minus discount<br/>Hive box cart put items]

                T_Clients[👥 ClientsScreen Widget<br/>━━━━━<br/>class ClientsScreen extends ConsumerStatefulWidget<br/>DataTable2 widget<br/>SearchDelegate implementation<br/>CRUD operations with Firestore<br/>Form validation<br/>Pagination support]

                T_Stock[📊 StockDashboardScreen Widget<br/>━━━━━<br/>class StockDashboardScreen extends ConsumerWidget<br/>ref watch warehouseStockProvider StreamProvider<br/>fl chart 0.63.0 for PieChart BarChart<br/>DataTable2 for warehouse comparison<br/>Firebase paths warehouses 999 CA CA1-4 etc<br/>Stock thresholds low 10 medium 50 good 50<br/>SharedPreferences utilization percent capacity]

                T_SpareParts[🔧 SparePartsScreen Widget<br/>━━━━━<br/>class SparePartsScreen extends ConsumerWidget<br/>ref watch sparePartsProvider StreamProvider<br/>Firebase ref spareparts onValue stream<br/>94 items with warehouse_stock Map<br/>GridView crossAxisCount ResponsiveHelper getColumns<br/>FilterChip categories clips filters belts<br/>Total stock 1716 units across warehouses]

                T_Quotes[📄 QuotesScreen Widget<br/>━━━━━<br/>class QuotesScreen extends ConsumerStatefulWidget<br/>ref watch quotesProvider StreamProvider<br/>Search and filter implementation<br/>Status badges Draft Sent Viewed<br/>Bulk operations support<br/>Export functionality]
            end

            subgraph "Admin Widgets"
                T_AdminPanel[🛡️ AdminPanelScreen Widget<br/>━━━━━<br/>class AdminPanelScreen extends ConsumerStatefulWidget<br/>Access EnvConfig isSuperAdminEmail<br/>Admin emails andres turboairmexico com<br/>NavigationRail with 8 destinations<br/>IndexedStack for tab persistence<br/>SharedPreferences selectedIndex]

                T_Performance[📈 PerformanceDashboardScreen<br/>━━━━━<br/>class PerformanceDashboardScreen extends ConsumerWidget<br/>ref watch userPerformanceProvider FutureProvider<br/>Aggregation quotes where userId aggregate<br/>KPI calculations conversionRate quotes opportunities<br/>Charts package charts flutter<br/>Export pdf Document and excel Excel]

                T_UserMgmt[👥 UserInfoDashboardScreen<br/>━━━━━<br/>class UserInfoDashboardScreen extends ConsumerStatefulWidget<br/>PaginatedDataTable<br/>Firebase Admin SDK calls<br/>User role mutations<br/>Activity tracking<br/>Permission matrix]

                T_ErrorMon[⚠️ OptimizedErrorMonitoringDashboard<br/>━━━━━<br/>class OptimizedErrorMonitoringDashboard extends ConsumerWidget<br/>Timeline widget<br/>StackTrace parsing<br/>Error categorization<br/>Resolution tracking<br/>Export functionality]
            end
        end

        subgraph "⚡ RIVERPOD STATE MANAGEMENT"
            subgraph "Provider Definitions"
                T_AuthProvider[🔐 authStateProvider<br/>━━━━━<br/>final authStateProvider StreamProvider autoDispose User<br/>return FirebaseAuth instance authStateChanges<br/>Token refresh FirebaseAuth instance idTokenChanges<br/>Custom claims user getIdTokenResult claims]

                T_CartProvider[🛒 cartItemsProvider<br/>━━━━━<br/>final cartItemsProvider StateNotifierProvider CartNotifier List CartItem<br/>return CartNotifier ref<br/>class CartNotifier extends StateNotifier List CartItem<br/>Hive box CartItem cart_items<br/>Methods add remove updateQuantity clear]

                T_ProductProvider[📦 productsProvider<br/>━━━━━<br/>final productsProvider StreamProvider autoDispose List Product<br/>return FirebaseDatabase instance ref products onValue<br/>map event parseProducts event snapshot<br/>Indexing orderByChild sku<br/>Caching keepAlive true]

                T_ClientProvider[👥 clientsProvider<br/>━━━━━<br/>final clientsProvider FutureProvider family<br/>User scoped queries<br/>Client CRUD operations<br/>Pagination support<br/>Search functionality]

                T_StockProvider[📊 warehouseStockProvider<br/>━━━━━<br/>final warehouseStockProvider StreamProvider autoDispose Map String StockLevel<br/>final warehouses 999 CA CA1 CA2 CA3 CA4<br/>COCZ COPZ INT MEE PU SI XCA XPU XZRE ZRE<br/>return combineLatest warehouses map<br/>FirebaseDatabase instance ref warehouses onValue<br/>Aggregation reduce mergeStock]

                T_SparePartsProvider[🔧 sparePartsProvider<br/>━━━━━<br/>final sparePartsProvider StreamProvider autoDispose List SparePart<br/>return FirebaseDatabase instance ref spareparts onValue<br/>map event parseSpareParts event snapshot<br/>Model SparePart fromMap key Map String dynamic<br/>warehouse_stock Map String int with 16 keys]

                T_QuoteProvider[📄 quoteProvider<br/>━━━━━<br/>final quoteProvider StreamProvider family<br/>Quote model mapping<br/>Status tracking<br/>Client relations<br/>Product items array]
            end
        end

        subgraph "🔀 ROUTING - GoRouter"
            T_Router[🗺️ Router Configuration<br/>━━━━━<br/>final routerProvider Provider GoRouter<br/>final authState ref watch authStateProvider<br/>return GoRouter initialLocation<br/>redirect context state authRedirect authState<br/>routes route definitions<br/>Deep linking enabled<br/>URL strategy PathUrlStrategy]

            T_Routes[📍 Route Definitions<br/>━━━━━<br/>Routes / /products /products/:id /cart<br/>/clients /quotes /quotes/:id /stock<br/>/spareparts /profile /settings /admin/*<br/>Guards authGuard adminGuard<br/>Parameters pathParameters queryParameters<br/>ShellRoute MainNavigationShell]

            T_AuthGuard[🚪 Auth Middleware<br/>━━━━━<br/>authState valueOrNull check<br/>Role based redirects<br/>EnvConfig isSuperAdminEmail<br/>Deep link preservation<br/>Session validation]
        end
    end

    subgraph "⚙️ BACKEND - Technical Implementation"
        subgraph "☁️ FIREBASE SERVICES"
            T_FbAuth[🔐 Firebase Authentication<br/>━━━━━<br/>SDK firebase_auth 4.15.0<br/>Methods signInWithEmailAndPassword<br/>createUserWithEmailAndPassword<br/>sendPasswordResetEmail<br/>JWT tokens exp 3600s refresh 2592000s<br/>Custom claims role permissions array<br/>Multi-factor SMS TOTP ready]

            T_FbRTDB[💾 Firebase Realtime Database<br/>━━━━━<br/>SDK firebase_database 10.3.0<br/>Protocol WebSocket wss<br/>Structure JSON tree max depth 32<br/>Offline enablePersistence<br/>Cache 100MB limit<br/>Rules read write validate<br/>Indexes indexOn sku createdAt]

            T_FbStorage[📁 Firebase Cloud Storage<br/>━━━━━<br/>SDK firebase_storage 11.5.0<br/>Bucket gs taquotes firebasestorage app<br/>Files 3534 images 1.2GB total<br/>Structure thumbnails SKU screenshots SKU<br/>CDN Fastly 76 edge locations<br/>Transformations w 300 h 300<br/>CORS enabled for web]

            T_FbHosting[🌐 Firebase Hosting<br/>━━━━━<br/>Domain taquotes web app<br/>SSL auto provisioned Lets Encrypt<br/>Headers cache control max age 3600<br/>Rewrites /** to index html<br/>Deploy firebase deploy only hosting<br/>Version history 100 versions kept<br/>Rollback instant]

            T_FbFunctions[⚡ Cloud Functions v2<br/>━━━━━<br/>Node js 18 runtime<br/>Express js framework<br/>Pub Sub triggers<br/>VPC connector support<br/>Auto scaling<br/>Error handling]
        end

        subgraph "💾 DATABASE SCHEMA"
            T_Products_Schema[📦 /products/{productId}<br/>━━━━━<br/>interface Product<br/>sku string indexed<br/>model string<br/>name string<br/>description string<br/>price number<br/>category string<br/>subcategory string<br/>thumbnailUrl string CDN URL<br/>imageUrl string P.1<br/>imageUrl2 string P.2<br/>dimensions w d h number<br/>weight number<br/>Count 835 documents<br/>Size 2.5MB]

            T_Clients_Schema[👥 /clients/{userId}/{clientId}<br/>━━━━━<br/>interface Client<br/>company string<br/>contactName string<br/>email string<br/>phone string<br/>address string<br/>taxId string<br/>creditTerms string<br/>notes string<br/>createdAt timestamp<br/>updatedAt timestamp]

            T_Quotes_Schema[📄 /quotes/{userId}/{quoteId}<br/>━━━━━<br/>interface Quote<br/>quoteNumber string TAQ-YYYY-###<br/>clientId string<br/>items array CartItem<br/>subtotal number<br/>tax number<br/>discount number<br/>total number<br/>status string<br/>createdAt timestamp<br/>validUntil timestamp]

            T_Warehouses_Schema[🏭 /warehouses/{warehouseId}<br/>━━━━━<br/>Warehouses 999 CA CA1 CA2 CA3 CA4<br/>COCZ COPZ INT MEE PU SI XCA XPU XZRE ZRE<br/>interface WarehouseStock<br/>productSku string<br/>available number<br/>reserved number<br/>reorderPoint number<br/>lastUpdated timestamp<br/>Updates real time via transactions]

            T_SpareParts_Schema[🔧 /spareparts/{partId}<br/>━━━━━<br/>interface SparePart<br/>sku string<br/>name string<br/>description string<br/>price number<br/>warehouse_stock<br/>warehouseId string number<br/>category string<br/>compatibility string array<br/>Count 94 items<br/>Total units 1716]

            T_Users_Schema[👤 /users/{userId}<br/>━━━━━<br/>interface UserProfile<br/>email string<br/>name string<br/>role string<br/>permissions array<br/>preferences object<br/>lastLogin timestamp<br/>createdAt timestamp<br/>commissionRate number]
        end

        subgraph "🔧 BUSINESS LOGIC"
            T_PriceCalc[🧮 Price Calculation Service<br/>━━━━━<br/>class PriceCalculator<br/>calculateLineTotal qty int price double double<br/>calculateSubtotal items List CartItem double<br/>calculateTax subtotal double rate double 0.08 double<br/>applyDiscount amount double discount Discount double<br/>calculateGrandTotal double<br/>Precision Decimal package scale 2<br/>Format NumberFormat currency symbol dollar]

            T_QuoteGen[📋 Quote Generation Service<br/>━━━━━<br/>class QuoteGenerator<br/>generateQuoteNumber String TAQ-YYYY-###<br/>createPDF quote Quote Future Uint8List<br/>addSignature pdf PdfDocument signature Uint8List<br/>Package pdf 3.10.7<br/>Fonts Roboto embedded<br/>Size 200KB per quote]

            T_EmailSvc[✉️ Email Service<br/>━━━━━<br/>class EmailService<br/>sendQuoteEmail quote Quote attachments List Attachment<br/>Package mailer 6.0.1<br/>SMTP smtp gmail com 587<br/>Auth OAuth2 or App Password<br/>Attachments StreamAttachment for memory efficiency<br/>Queue retry with exponential backoff]

            T_ExportSvc[📊 Export Service<br/>━━━━━<br/>class ExportService<br/>exportToExcel data Future Uint8List<br/>Package excel 2.0.0<br/>XLSX generation<br/>Formula support<br/>10000 row limit<br/>Multiple sheets]
        end

        subgraph "🌐 EXTERNAL INTEGRATIONS"
            T_Gmail[📧 Gmail SMTP API<br/>━━━━━<br/>smtp gmail com 587<br/>OAuth 2.0 authentication<br/>MIME multipart messages<br/>25MB attachment limit<br/>Retry logic<br/>Delivery tracking]

            T_CDN[🚀 Fastly CDN<br/>━━━━━<br/>Edge locations 76 POPs<br/>Cache Control headers<br/>Image optimization<br/>Brotli compression<br/>Global distribution<br/>99.9 percent uptime]
        end
    end

    subgraph "🔒 SECURITY & PERFORMANCE"
        subgraph "Security Implementation"
            T_TLS[🔐 TLS 1.3<br/>━━━━━<br/>ECDHE RSA AES256 GCM SHA384<br/>HSTS enabled<br/>Certificate pinning<br/>OCSP stapling]

            T_CSRF[🛡️ CSRF Protection<br/>━━━━━<br/>Double submit cookies<br/>SameSite Strict<br/>Random secure tokens<br/>Per session rotation]

            T_RateLimit[⏱️ Rate Limiter<br/>━━━━━<br/>Token bucket algorithm<br/>100 req min per IP<br/>Exponential backoff<br/>Redis based tracking]

            T_RBAC[👤 RBAC Implementation<br/>━━━━━<br/>Custom claims in JWT<br/>Middleware enforcement<br/>Resource based permissions<br/>Audit logging]

            T_Session[⏰ Session Management<br/>━━━━━<br/>30 min idle timeout<br/>JWT exp 1 hour<br/>Refresh token 30 days<br/>Secure cookie flags]
        end

        subgraph "Performance Optimizations"
            T_Cache[💾 Hive Cache<br/>━━━━━<br/>hive 2.2.3<br/>100MB max size<br/>LRU eviction<br/>AES encryption]

            T_LazyLoad[📜 Lazy Loading<br/>━━━━━<br/>Initial 24 items<br/>Scroll threshold 80 percent<br/>Batch size 12<br/>Virtual scrolling]

            T_Offline[📡 Offline Queue<br/>━━━━━<br/>connectivity plus 5.0.0<br/>Operation queue<br/>Conflict resolution<br/>Sync on reconnect]

            T_Performance[⚡ Performance Metrics<br/>━━━━━<br/>First Paint 1.2s target less 1.5s<br/>Time to Interactive 2.1s target less 2.5s<br/>Bundle size 3.4MB gzipped<br/>Lighthouse Score 92<br/>API response time p95 less 200ms<br/>Database queries p99 less 100ms<br/>Image CDN latency 50ms<br/>WebSocket latency 10ms]
        end
    end

    T_Login --> T_AuthProvider
    T_Products --> T_ProductProvider
    T_Cart --> T_CartProvider
    T_Stock --> T_StockProvider
    T_SpareParts --> T_SparePartsProvider
    T_Clients --> T_ClientProvider
    T_Quotes --> T_QuoteProvider

    T_AuthProvider --> T_FbAuth
    T_ProductProvider --> T_FbRTDB
    T_CartProvider --> T_FbRTDB
    T_StockProvider --> T_Warehouses_Schema
    T_SparePartsProvider --> T_SpareParts_Schema
    T_ClientProvider --> T_Clients_Schema
    T_QuoteProvider --> T_Quotes_Schema

    T_FbRTDB --> T_Products_Schema
    T_FbRTDB --> T_Warehouses_Schema
    T_FbRTDB --> T_SpareParts_Schema

    T_Router --> T_Routes
    T_Routes --> T_AuthGuard
    T_AuthGuard --> T_RBAC

    T_Cart --> T_PriceCalc
    T_QuoteGen --> T_EmailSvc
    T_EmailSvc --> T_Gmail
    T_FbStorage --> T_CDN

    classDef techWidget fill:#1a237e,stroke:#000051,stroke-width:3px,color:#fff
    classDef techProvider fill:#4a148c,stroke:#12005e,stroke-width:3px,color:#fff
    classDef techFirebase fill:#f57c00,stroke:#bb4d00,stroke-width:3px,color:#fff
    classDef techSchema fill:#1b5e20,stroke:#003300,stroke-width:3px,color:#fff
    classDef techService fill:#b71c1c,stroke:#7f0000,stroke-width:3px,color:#fff
    classDef techSecurity fill:#263238,stroke:#000a12,stroke-width:3px,color:#fff
    classDef techExternal fill:#0d47a1,stroke:#002171,stroke-width:3px,color:#fff

    class T_Login,T_Register,T_Home,T_Products,T_Cart,T_Stock,T_SpareParts,T_AdminPanel,T_Performance techWidget
    class T_AuthProvider,T_CartProvider,T_ProductProvider,T_StockProvider,T_SparePartsProvider techProvider
    class T_FbAuth,T_FbRTDB,T_FbStorage,T_FbHosting,T_FbFunctions techFirebase
    class T_Products_Schema,T_Warehouses_Schema,T_SpareParts_Schema,T_Clients_Schema,T_Quotes_Schema techSchema
    class T_PriceCalc,T_QuoteGen,T_EmailSvc,T_ExportSvc techService
    class T_TLS,T_CSRF,T_RateLimit,T_RBAC,T_Session,T_Cache,T_LazyLoad,T_Offline techSecurity
    class T_Gmail,T_CDN techExternal
```

## Technical Stack Summary

### Frontend Technologies
- **Framework**: Flutter SDK 3.16.0
- **Language**: Dart 3.2.0
- **State Management**: Riverpod 2.4.9
- **Navigation**: GoRouter 12.1.3
- **Local Storage**: Hive 2.2.3
- **Image Caching**: CachedNetworkImage 3.3.0
- **Charts**: fl_chart 0.63.0
- **PDF**: pdf 3.10.7
- **Email**: mailer 6.0.1

### Backend Technologies
- **Platform**: Firebase (BaaS)
- **Authentication**: Firebase Auth 4.15.0
- **Database**: Firebase Realtime Database 10.3.0
- **Storage**: Firebase Cloud Storage 11.5.0
- **Hosting**: Firebase Hosting
- **Functions**: Cloud Functions v2 (Node.js 18)
- **CDN**: Fastly (76 edge locations)

### Architecture Patterns
- **Clean Architecture** layers separation
- **Repository Pattern** for data access
- **Provider Pattern** for dependency injection
- **BLoC Pattern** for complex flows
- **Factory Pattern** for model creation
- **Observer Pattern** for reactive streams
- **Singleton Pattern** for services

### Security Implementations
- **TLS 1.3** with ECDHE-RSA-AES256-GCM-SHA384
- **JWT Tokens** with 1-hour expiration
- **CSRF Protection** with double-submit cookies
- **Rate Limiting** 100 requests/minute per IP
- **RBAC** with custom JWT claims
- **Session Timeout** 30 minutes idle
- **Input Validation** with sanitization
- **CORS** properly configured

### Performance Metrics
- **First Contentful Paint**: 1.2s
- **Time to Interactive**: 2.1s
- **Lighthouse Score**: 92
- **Bundle Size**: 3.4MB gzipped
- **API Response**: p95 < 200ms
- **Database Queries**: p99 < 100ms
- **CDN Latency**: 50ms average
- **WebSocket Latency**: 10ms