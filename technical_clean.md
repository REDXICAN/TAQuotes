graph TD
    subgraph "🎯 PRESENTATION LAYER"
        UI[Flutter UI Layer<br/>━━━━━━━━━<br/>Material Design 3.0<br/>Responsive Layout]

        UI --> Screens[Screen Widgets]
        Screens --> Auth_W[🔐 Authentication<br/>LoginScreen<br/>RegisterScreen<br/>ForgotPasswordScreen]
        Screens --> Main_W[📱 Main Screens<br/>ProductsScreen<br/>CartScreen<br/>ClientsScreen<br/>QuotesScreen]
        Screens --> Admin_W[🛡️ Admin Screens<br/>AdminPanelScreen<br/>PerformanceDashboard<br/>UserManagement]

        UI --> Components[Reusable Components]
        Components --> Forms[Form Widgets<br/>TextFormField<br/>Validators<br/>Controllers]
        Components --> Lists[List Widgets<br/>ListView.builder<br/>GridView<br/>DataTable2]
        Components --> Charts[Chart Widgets<br/>fl_chart 0.63.0<br/>PieChart<br/>BarChart]
    end

    subgraph "🔄 STATE MANAGEMENT LAYER"
        State[Riverpod 2.4.9<br/>━━━━━━━━━<br/>Reactive State Management]

        State --> Providers[Provider Types]
        Providers --> Stream_P[StreamProvider<br/>autoDispose<br/>Real-time Updates]
        Providers --> State_P[StateProvider<br/>Simple State<br/>Synchronous]
        Providers --> StateNotifier_P[StateNotifierProvider<br/>Complex Logic<br/>Immutable State]

        State --> AppProviders[App Providers]
        AppProviders --> Auth_P[authStateProvider<br/>User Authentication<br/>JWT Tokens]
        AppProviders --> Cart_P[cartItemsProvider<br/>Cart Management<br/>Hive Persistence]
        AppProviders --> Product_P[productsProvider<br/>835 Products<br/>Real-time Sync]
    end

    subgraph "🏗️ BUSINESS LOGIC LAYER"
        Business[Business Services<br/>━━━━━━━━━<br/>Core Logic]

        Business --> Services
        Services --> Price_S[PriceCalculator<br/>• Line totals<br/>• Tax 8%<br/>• Discounts %/$<br/>• Grand total]
        Services --> Quote_S[QuoteGenerator<br/>• TAQ-YYYY-###<br/>• PDF creation<br/>• Signatures]
        Services --> Email_S[EmailService<br/>• SMTP Gmail<br/>• Attachments<br/>• Retry logic]
        Services --> Export_S[ExportService<br/>• Excel export<br/>• 10k limit<br/>• Formulas]
    end

    subgraph "📊 DATA LAYER"
        Data[Data Access<br/>━━━━━━━━━<br/>Firebase Integration]

        Data --> Firebase
        Firebase --> FB_Auth[Firebase Auth<br/>JWT tokens<br/>Role claims<br/>Session mgmt]
        Firebase --> FB_DB[Realtime Database<br/>WebSocket<br/>100MB cache<br/>Offline sync]
        Firebase --> FB_Storage[Cloud Storage<br/>3,534 images<br/>CDN Fastly<br/>Transformations]

        Data --> Local
        Local --> Hive_DB[Hive 2.2.3<br/>Local storage<br/>Cart persistence<br/>Preferences]
        Local --> Secure[SecureStorage<br/>Token storage<br/>Credentials<br/>Encryption]
    end

    subgraph "🔒 INFRASTRUCTURE LAYER"
        Infra[Infrastructure<br/>━━━━━━━━━<br/>Security & Performance]

        Infra --> Security
        Security --> TLS[TLS 1.3<br/>ECDHE-RSA<br/>256-bit]
        Security --> CSRF[CSRF Protection<br/>Double-submit<br/>Token rotation]
        Security --> Rate[Rate Limiting<br/>100 req/min<br/>IP tracking]

        Infra --> Performance
        Performance --> Cache[Caching<br/>100MB Hive<br/>LRU eviction]
        Performance --> Lazy[Lazy Loading<br/>24 initial<br/>+12 on scroll]
        Performance --> Metrics[Metrics<br/>FCP: 1.2s<br/>TTI: 2.1s<br/>Score: 92]
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