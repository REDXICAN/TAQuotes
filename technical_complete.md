flowchart TB
    subgraph PRESENTATION["🎯 PRESENTATION LAYER - Flutter UI"]
        direction TB
        UI["`**Flutter SDK >=3.1.0 <4.0.0**
        ━━━━━━━━━
        • Material Design 3.0
        • Responsive breakpoints
        • Dark/Light themes
        • RTL support
        • Accessibility WCAG 2.1
        • 24 Total Screens`"]

        UI --> Screens["`**Screen Widgets Architecture**
        ━━━━━━━━━
        ConsumerWidget base
        StatefulConsumer lifecycle
        HookConsumer reactive
        GoRouter 15.1.2 navigation`"]

        Screens --> Auth_W["`**🔐 Authentication (4 Screens)**
        ━━━━━━━━━
        LoginScreen:
        • Email regex validation
        • Remember me 30 days
        • Auto-login SharedPrefs
        • Error state handling
        RegisterScreen:
        • 4 role types enum
        • Email verification flow
        • Password strength meter
        • Terms acceptance bool
        ForgotPasswordScreen:
        • Email validation
        • Reset token 1hr expiry
        • Firebase Auth integration
        SplashScreen:
        • Logo animation
        • Auth check logic`"]

        Screens --> Main_W["`**📱 Core Business (8 Screens)**
        ━━━━━━━━━
        ProductsScreen:
        • 1,098 products StreamProvider
        • Lazy loading 24+12 items
        • Search debounced 300ms
        • 12 category filters
        • Price range double slider
        • Sort 6 criteria enum
        CartScreen:
        • Line items StateNotifier
        • Quantity int validators
        • Price calculations double
        • Tax 8% const
        • Discounts %/$ TextEditingController
        • Client dropdown SearchableDropdown
        • Comments ExpansionTile
        ClientsScreen:
        • DataTable2 sortable
        • CRUD operations Future
        • Validation FormState
        • Search case-insensitive
        • Excel import/export
        • 10k row limit const
        QuotesScreen:
        • Status filters enum
        • DateRangePicker widget
        • PDF generation async
        • StreamAttachment email
        • Duplicate deepCopy
        • Edit FormBuilder`"]

        Screens --> Admin_W["`**🛡️ Admin Panels (6 Screens)**
        ━━━━━━━━━
        AdminPanelScreen:
        • User CRUD Firebase
        • Role assignment claims
        • Permission matrix Map
        • Activity logs Stream
        • Settings SharedPrefs
        PerformanceDashboard:
        • fl_chart 0.69.0
        • Revenue calculations
        • User metrics Map
        • Top 10 performers sort
        • Period selectors DateTime
        StockDashboard:
        • 16 warehouses array
        • Real-time Firebase
        • Color indicators enum
        • Pie charts widgets
        UserManagement:
        • Approval queue Stream
        • Bulk actions batch
        • Filter chips bool
        • Status indicators enum
        DatabaseTools:
        • Backup trigger Future
        • Import FilePicker
        • Export options dialog
        • Integrity check async
        ErrorMonitor:
        • Real-time tracking
        • Resolution system
        • Export logs CSV`"]

        UI --> Components["`**Reusable Widget Library**
        ━━━━━━━━━
        150+ custom widgets
        Component inheritance
        Builder patterns`"]

        Components --> Forms["`**Form Components**
        ━━━━━━━━━
        TextFormField:
        • 12 validators regex
        • InputFormatters masks
        • Error messages i18n
        • Icons Material
        SearchableDropdown:
        • 500+ items ListView
        • Async loading Future
        • Custom itemBuilder
        • Debounce 300ms
        DatePicker:
        • Range selection
        • Disabled dates Set
        • intl 0.20.2 format`"]

        Components --> Lists["`**List Components**
        ━━━━━━━━━
        ListView.builder:
        • Infinite scroll detector
        • Pull RefreshIndicator
        • SeparatorBuilder widget
        • Empty state placeholder
        GridView.extent:
        • Responsive columns calc
        • Aspect ratio 1.2
        • CrossAxisSpacing 16
        DataTable2:
        • Sort callbacks
        • Fixed headers sticky
        • Row selection Set
        • Pagination 50/page`"]

        Components --> Charts["`**fl_chart 0.69.0**
        ━━━━━━━━━
        PieChart:
        • Touch callbacks
        • AnimationController
        • Custom colors List
        • Value labels Text
        BarChart:
        • Grouped BarChartGroupData
        • Tooltips overlay
        • GridData lines
        • Axis FlTitlesData
        LineChart:
        • Multiple LineBarsData
        • Area gradient fill
        • FlDotData indicators
        • Zoom pan gestures`"]
    end

    subgraph STATE["🔄 STATE - Riverpod 2.4.9"]
        direction TB
        State["`**State Management Core**
        ━━━━━━━━━
        • ProviderScope root
        • ProviderObserver logger
        • AsyncValue handling
        • DevTools integration
        • Error boundaries try/catch
        • 759 provider occurrences`"]

        State --> Providers["`**Provider Architecture**
        ━━━━━━━━━
        53 files with providers
        Naming convention
        Dependency injection
        Family providers`"]

        Providers --> Stream_P["`**StreamProvider.autoDispose**
        ━━━━━━━━━
        • 27 files implementation
        • AsyncValue<T> wrapper
        • Error recovery fallback
        • Loading shimmer states
        • Cache until dispose
        • 30 second refresh interval
        Real-time streams:
        • Products Firebase
        • Stock WebSocket
        • Clients onChange
        • Quotes status
        • User activity`"]

        Providers --> State_P["`**StateProvider Pattern**
        ━━━━━━━━━
        • Synchronous T state
        • Direct ref.read mutations
        • No business logic
        • UI state only
        Used for:
        • Selected filters bool
        • Sort options enum
        • View modes string
        • Expansion states bool
        • Form values Map`"]

        Providers --> StateNotifier_P["`**StateNotifierProvider**
        ━━━━━━━━━
        • Immutable state freezed
        • Protected mutations
        • Business logic methods
        • Side effects Future
        • Async operations
        Controllers:
        • CartNotifier List<Item>
        • AuthNotifier User?
        • FilterNotifier Map
        • SearchNotifier String
        • ThemeNotifier bool`"]

        State --> AppProviders["`**Core Providers**
        ━━━━━━━━━
        Business providers
        Firebase integration
        Service providers`"]

        AppProviders --> Auth_P["`**authStateProvider**
        ━━━━━━━━━
        • FirebaseAuth.authStateChanges()
        • JWT token 1hr expiry
        • RefreshToken 30d
        • Claims customClaims
        • Role checking hasRole()
        • Session 30min timeout
        • Multi-device deviceIds
        • Logout signOut()
        • Reset sendPasswordReset`"]

        AppProviders --> Cart_P["`**cartItemsProvider**
        ━━━━━━━━━
        • List<CartItem> state
        • Add/Remove methods
        • Quantity validation >0
        • Price recalculation
        • Discount application
        • Tax computation 0.08
        • Hive persistence Box
        • Session recovery init
        • Clear on logout dispose`"]

        AppProviders --> Product_P["`**productsProvider**
        ━━━━━━━━━
        • 1,098 products Stream
        • Firebase.database.ref
        • Category filtering where
        • Search Fuse.js index
        • Sort algorithms compareTo
        • Image URL mapping CDN
        • Stock integration join
        • Price updates onValue`"]
    end

    subgraph BUSINESS["🏗️ BUSINESS - Services Layer"]
        direction TB
        Business["`**Service Layer Pattern**
        ━━━━━━━━━
        • Singleton getInstance()
        • DI with Riverpod
        • Error handling try/catch
        • Retry logic exponential
        • Circuit breakers 5 fails
        • 25+ service classes`"]

        Business --> Services["`**Business Services**
        ━━━━━━━━━
        Interface segregation
        SOLID principles
        Repository pattern
        Domain driven design`"]

        Services --> Price_S["`**PriceCalculatorService**
        ━━━━━━━━━
        Methods:
        • calculateLineTotal(int, double)
        • calculateSubtotal(List)
        • applyDiscount(double, enum)
        • calculateTax(double, 0.08)
        • calculateGrandTotal()
        Features:
        • intl NumberFormat currency
        • Decimal precision .toStringAsFixed(2)
        • Discount validation 0-100%
        • Tax exemptions bool
        • Bulk pricing Map<int,double>`"]

        Services --> Quote_S["`**QuoteGeneratorService**
        ━━━━━━━━━
        Generation:
        • Q2025XXX format String
        • Sequential increment++
        • Duplicate detection Set
        • Version tracking int
        PDF Creation:
        • pdf 3.10.7 package
        • pw.Document builder
        • Logo MemoryImage embed
        • Digital signature pw.Widget
        • Barcode pw.Barcode.code128
        • 30-day DateTime validity`"]

        Services --> Email_S["`**EmailService mailer 6.0.1**
        ━━━━━━━━━
        Configuration:
        • smtp.gmail.com:587
        • OAuth2 authentication
        • .env app password
        • TLS starttls enabled
        Features:
        • HTML templates String
        • StreamAttachment PDF
        • Retry 3 attempts loop
        • Queue List<Message>
        • Delivery tracking bool
        • Bounce handling catch`"]

        Services --> Export_S["`**ExportService excel 4.0.0**
        ━━━━━━━━━
        Excel Export:
        • Excel() constructor
        • 10,000 row limit const
        • Formula cells setValue
        • Multiple sheets Map
        • CellStyle formatting
        CSV Export:
        • UTF-8 encoding utf8
        • Custom delimiters String
        • Header row List
        • Quote escaping replaceAll
        Batch Operations:
        • Progress Stream<double>
        • CancellationToken cancel
        • Memory efficient chunks`"]
    end

    subgraph DATA["📊 DATA LAYER - Firebase & Local"]
        direction TB
        Data["`**Data Access Layer**
        ━━━━━━━━━
        • Repository pattern abstract
        • DAO interfaces
        • Cache strategy LRU
        • Sync Queue<Operation>
        • Conflict resolution merge
        • Platform specific conditional`"]

        Data --> Firebase["`**Firebase Backend**
        ━━━━━━━━━
        Project: taquotes
        Region: us-central1
        Tier: Blaze plan
        SDK: firebase_core 4.0.0`"]

        Firebase --> FB_Auth["`**Firebase Auth 6.0.1**
        ━━━━━━━━━
        Methods:
        • signInWithEmailAndPassword
        • GoogleAuthProvider OAuth
        • sendPasswordResetEmail
        • sendEmailVerification
        Features:
        • IdTokenResult JWT 1hr
        • refreshToken() 30d
        • setCustomUserClaims
        • User.uid unique
        • multiFactor 2FA
        • revokeRefreshTokens
        • Security rules .read/.write`"]

        Firebase --> FB_DB["`**Realtime Database 12.0.0**
        ━━━━━━━━━
        Structure paths:
        • /products (1,098 items)
        • /clients/$uid (500+)
        • /quotes/$uid (1000+)
        • /spareparts (dynamic)
        • /warehouses/16 locations
        • /users/$uid/profile
        Features:
        • DatabaseReference.onValue
        • keepSynced(true) offline
        • 100MB setPersistenceCacheSizeBytes
        • runTransaction atomic
        • ServerValue.timestamp
        • Rules JSON security
        • exportValToFile backup`"]

        Firebase --> FB_Storage["`**Cloud Storage 13.0.0**
        ━━━━━━━━━
        Bucket: taquotes.firebasestorage.app
        Content paths:
        • /products/thumbnails/ 1,454
        • /products/screenshots/ 2,080
        • /quotes/pdfs/ generated
        • /users/avatars/ profile
        CDN Config:
        • Fastly integration headers
        • 76 edge POPs worldwide
        • resize=w:400 transforms
        • format=webp conversion
        • loading=lazy attribute
        • 100GB bandwidth/month`"]

        Data --> Local["`**Local Storage Layers**
        ━━━━━━━━━
        Platform conditional imports
        Offline-first architecture
        Encrypted SecureStorage`"]

        Local --> Hive_DB["`**Hive 2.2.3 NoSQL**
        ━━━━━━━━━
        Boxes registered:
        • cart_items Box<CartItem>
        • user_preferences Box<Map>
        • cached_products LazyBox
        • offline_queue Box<Operation>
        • search_history Box<String>
        Features:
        • 100MB maxSizeInBytes
        • LRU eviction policy
        • AES-256 encryption key
        • TypeAdapter<T> codegen
        • LazyBox async loading
        • compact() defragment`"]

        Local --> Secure["`**flutter_secure_storage**
        ━━━━━━━━━
        Storage keys:
        • jwt_token String
        • refresh_token String
        • api_keys Map
        • user_credentials JSON
        • session_data encrypted
        Platform Security:
        • Keychain iOS AES
        • Keystore Android RSA
        • Credential API Web
        • DPAPI Windows
        • libsecret Linux`"]
    end

    subgraph INFRA["🔒 INFRASTRUCTURE - Security & Performance"]
        direction TB
        Infra["`**Infrastructure Layer**
        ━━━━━━━━━
        • GitHub Actions CI/CD
        • Firebase Monitoring
        • Sentry error tracking
        • Daily backup cron
        • Disaster recovery plan
        • 99.9% uptime SLA`"]

        Infra --> Security["`**Security Implementation**
        ━━━━━━━━━
        OWASP Top 10 compliance
        Regular penetration tests
        Security headers configured
        CSP nonce-based`"]

        Security --> TLS["`**TLS Configuration**
        ━━━━━━━━━
        Protocol:
        • TLS 1.3 exclusive
        • ECDHE-RSA-AES256-GCM-SHA384
        • Forward secrecy ephemeral
        • OCSP stapling enabled
        Headers enforced:
        • Strict-Transport-Security max-age
        • Content-Security-Policy nonce
        • X-Frame-Options DENY
        • X-XSS-Protection 1; mode=block
        • Cross-Origin-Resource-Policy same-origin`"]

        Security --> CSRF["`**CSRF Protection Service**
        ━━━━━━━━━
        Implementation:
        • 32-byte Random.secure() token
        • 4-hour expiration DateTime
        • Double-submit cookie pattern
        • SameSite=Strict cookies
        • Origin verification headers
        • Referer check validation
        Token Management:
        • Cryptographic generation
        • Constant-time comparison
        • Secure transport HTTPS
        • HttpOnly cookie flag`"]

        Security --> Rate["`**Rate Limiting Service**
        ━━━━━━━━━
        Limits enforced:
        • 100 req/min/IP general
        • 5 login/15min attempts
        • 3 reset/hour password
        • 20 email/min sending
        • 50 quotes/hour creation
        Implementation:
        • Map<String,List> tracking
        • IP allowlist Set<String>
        • Exponential backoff Duration
        • ReCaptcha v3 trigger
        • Block duration 1-24hr
        • Cleanup Timer.periodic(5min)`"]

        Infra --> Performance["`**Performance Optimization**
        ━━━━━━━━━
        Lighthouse score 92/100
        FCP 1.2s target
        TTI 2.1s interactive
        Memory profiling
        Bundle optimization`"]

        Performance --> Cache["`**Cache Strategy Layers**
        ━━━━━━━━━
        Browser Cache:
        • Service worker v2
        • Cache-Control headers
        • 1 year static assets
        CDN Cache:
        • Firebase Hosting edge
        • CloudFlare 120s TTL
        API Cache:
        • Redis equivalent Map
        • 5 minute TTL const
        Database Cache:
        • 100MB Firebase offline
        • Hive local persistence
        Widget Cache:
        • AutomaticKeepAliveClientMixin
        • const constructors`"]

        Performance --> Lazy["`**Lazy Loading Strategy**
        ━━━━━━━━━
        Implementation:
        • Initial desktop 24 items
        • Initial mobile 12 items
        • Scroll increment +24/+12
        • Threshold 80% viewport
        • Buffer 2x viewport height
        • Placeholder Shimmer widgets
        Optimization:
        • ScrollController listener
        • Pagination cursor-based
        • InfiniteScrollPagination pkg
        • Skeleton screens loading
        • Progressive JPEG images
        • intersection_observer web`"]

        Performance --> Metrics["`**Performance Metrics**
        ━━━━━━━━━
        Web Vitals targets:
        • FCP 1.2s paint
        • TTI 2.1s interactive
        • LCP 2.5s contentful
        • CLS <0.1 layout shift
        • FID <100ms delay
        • INP <200ms interaction
        Monitoring stack:
        • Lighthouse CI automated
        • Firebase Performance SDK
        • Sentry performance traces
        • Custom analytics events
        • Real user monitoring RUM
        • 30-day retention logs`"]
    end

    classDef uiStyle fill:#e3f2fd,stroke:#1565c0,stroke-width:3px
    classDef stateStyle fill:#f3e5f5,stroke:#6a1b9a,stroke-width:3px
    classDef businessStyle fill:#fff3e0,stroke:#ef6c00,stroke-width:3px
    classDef dataStyle fill:#e8f5e9,stroke:#2e7d32,stroke-width:3px
    classDef infraStyle fill:#ffebee,stroke:#c62828,stroke-width:3px

    class UI,Screens,Components,Auth_W,Main_W,Admin_W,Forms,Lists,Charts uiStyle
    class State,Providers,AppProviders,Stream_P,State_P,StateNotifier_P,Auth_P,Cart_P,Product_P stateStyle
    class Business,Services,Price_S,Quote_S,Email_S,Export_S businessStyle
    class Data,Firebase,Local,FB_Auth,FB_DB,FB_Storage,Hive_DB,Secure dataStyle
    class Infra,Security,Performance,TLS,CSRF,Rate,Cache,Lazy,Metrics infraStyle