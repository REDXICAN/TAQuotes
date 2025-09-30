flowchart TB
    Start(["`**🌐 TurboAir Quotes System**
    ━━━━━━━━━
    Web App: taquotes.web.app
    1,098 Products with full specifications
    500+ Active Clients with CRM
    Dynamic Spare Parts from Firebase
    16 Global Warehouses with real-time tracking
    3,534 Product Images on CDN
    24 Total Application Screens`"])

    Start --> Frontend["`**🎨 FRONTEND**
    ━━━━━━━━━
    What Users See and Interact With
    Runs in Browser/Mobile/Desktop
    Responsive Design All Screens
    Dark/Light Theme Support
    Multi-language EN/ES
    Offline Mode 100MB Cache`"]

    Start --> Backend["`**⚙️ BACKEND**
    ━━━━━━━━━
    Server-Side Processing
    Real-time Data Sync
    Google Cloud Platform
    99.9% Uptime Achieved
    Auto-scaling for Traffic
    Global CDN Distribution`"]

    Frontend --> UserFlow["`**👤 Complete User Journey**
    ━━━━━━━━━
    7-Step Quote Process
    From Login to Email
    Average Time: 5 minutes
    Mobile and Desktop Support`"]

    Frontend --> Screens["`**📱 24 App Screens**
    ━━━━━━━━━
    Full Feature Set
    Professional UI/UX
    Material Design 3.0
    Accessibility Compliant`"]

    Frontend --> Memory["`**💾 Smart App Memory**
    ━━━━━━━━━
    Persistent Storage
    Auto-save Everything
    Offline Capabilities
    Sync When Online`"]

    UserFlow --> UF1["`**1️⃣ Visit Website**
    URL: taquotes.web.app
    Chrome/Safari/Edge/Firefox
    No download required
    Mobile responsive
    2-second load time`"]

    UserFlow --> UF2["`**2️⃣ Login Process**
    Email and Password
    Remember Me 30 days
    Forgot Password option
    2FA ready
    Multi-device support
    Session timeout 30min`"]

    UserFlow --> UF3["`**3️⃣ Browse Products**
    1,098 products available
    Filter by 12 categories
    Search name/SKU/desc
    Sort price/name/popular
    View thumbnails specs
    Check stock availability`"]

    UserFlow --> UF4["`**4️⃣ Build Cart**
    Add unlimited items
    Adjust quantities +/-
    Running subtotal
    Discounts % or $
    Discount reasons
    Tax 8% automatic
    View grand total
    Save draft quotes`"]

    UserFlow --> UF5["`**5️⃣ Select Client**
    500+ customers database
    Search name/email/phone
    View client history
    Add new client inline
    Edit client details
    Set credit terms
    Apply client discounts`"]

    UserFlow --> UF6["`**6️⃣ Generate Quote**
    Auto-number Q2025XXX
    Professional PDF layout
    Company logo branding
    Itemized product list
    All calculations shown
    Terms and conditions
    30-day validity
    Digital signature space`"]

    UserFlow --> UF7["`**7️⃣ Send Quote**
    Email with PDF attached
    Excel version available
    Custom email message
    CC/BCC support
    Delivery tracking
    Read receipts
    25MB attachment limit
    3 retry on failure`"]

    Screens --> AuthScreens["`**🔐 Authentication (4)**
    Login Screen
    Register Screen
    Forgot Password
    Splash Screen`"]

    Screens --> MainScreens["`**📊 Core Business (8)**
    Home Dashboard
    Products Catalog
    Clients Management
    Quotes System
    Cart Processing
    Spare Parts
    Projects`"]

    Screens --> AdminScreens["`**🛡️ Admin Only (6)**
    Admin Panel
    Performance Dashboard
    Stock Dashboard
    User Management
    Database Tools
    Error Monitor`"]

    AuthScreens --> Login["`**Login Screen**
    • Email/Password fields
    • Remember Me checkbox
    • Forgot Password link
    • Register new account
    • Social login ready
    • Error messages
    • Loading indicators
    • Password visibility`"]

    AuthScreens --> Register["`**Register Screen**
    • Full name input
    • Email verification
    • Password strength meter
    • Role selection
    • Company field
    • Phone number
    • Terms acceptance
    • CAPTCHA protection`"]

    AuthScreens --> ForgotPwd["`**Password Reset**
    • Email input field
    • Security questions
    • Reset link delivery
    • Token expiration 1hr
    • Success confirmation
    • Return to login`"]

    MainScreens --> Home["`**🏠 Home Dashboard**
    • Total products 1,098
    • Active clients 500+
    • Monthly quotes counter
    • Cart items badge
    • Quick action buttons
    • Recent activity feed
    • Performance metrics
    • Welcome message
    • News updates section`"]

    MainScreens --> Products["`**📦 Products Catalog**
    • 1,098 products display
    • 12 category tabs
    • Advanced search bar
    • Price $1,234.56 format
    • Thumbnail images CDN
    • Quick add to cart
    • Stock indicators
    • Load 24 then +12 scroll
    • Sort price/name/SKU
    • Filter by attributes
    • Compare products
    • Wishlist feature`"]

    MainScreens --> ProductDetail["`**🔍 Product Detail**
    • Multiple images P.1 P.2
    • Zoom capability
    • Full specifications
    • Dimensions W×D×H
    • Weight in lbs
    • Warranty info
    • Related products
    • Accessories list
    • Stock 16 warehouses
    • Quantity selector
    • Request info button
    • Download spec PDF
    • Share product link`"]

    MainScreens --> Cart["`**🛒 Shopping Cart**
    • Line items display
    • Product SKU/name
    • Quantity adjusters +/-
    • Unit price display
    • Line total calc
    • Remove item X button
    • Subtotal calculation
    • Tax calc 8% default
    • Discount % field
    • Discount $ field
    • Discount reason text
    • Grand total display
    • Client selector dropdown
    • Comments collapsible
    • Save draft button
    • Generate quote button
    • Clear cart option
    • Continue shopping`"]

    MainScreens --> Clients["`**👥 Clients Management**
    • 500+ client records
    • Company names
    • Contact persons
    • Email addresses
    • Phone numbers
    • Physical addresses
    • Tax ID numbers
    • Credit terms NET30
    • Add new client form
    • Edit client inline
    • Delete with confirm
    • Import from Excel
    • Export to Excel
    • Advanced search
    • Sort by columns
    • Client history
    • Notes section`"]

    MainScreens --> Stock["`**📊 Stock Dashboard**
    16 warehouse display:
    • 999 Reserved (Mexico)
    • CA California Main
    • CA1 CA2 CA3 CA4 (USA)
    • COCZ Cool Zone (Mexico)
    • COPZ Parts Zone (Mexico)
    • INT International
    • MEE Mexico Export
    • PU Pick Up Location
    • SI Special Inventory
    • XCA Export California
    • XPU Export Pick Up
    • XZRE Export Reserve
    • ZRE Zone Reserve
    Real-time stock levels
    Low stock alerts red
    Medium stock yellow
    Good stock green
    Category pie chart
    Total inventory value
    Reorder suggestions
    Movement history
    Comparison table
    Transfer requests`"]

    MainScreens --> SpareParts["`**🔧 Spare Parts**
    • Dynamic catalog from Firebase
    • Part numbers SKU
    • Spanish/English names
    • Real-time stock qty
    • By warehouse location
    • Unit prices display
    • Add to quote button
    • Category filters
    • Clips filters belts
    • Compatibility matrix
    • Supplier details
    • Lead times
    • Min order quantity
    • Bulk ordering
    • Export parts list`"]

    MainScreens --> Quotes["`**📄 Quotes Management**
    • All quotes list
    • Quote Q2025XXX format
    • Creation dates
    • Client names
    • Total amounts $
    • Status badges
    • Draft/Sent/Viewed
    • Search quotes box
    • Date range filter
    • Client filter
    • Status filter
    • View details
    • Duplicate quote
    • Edit drafts
    • Delete with confirm
    • Export to Excel
    • Bulk PDF export
    • Email quote again
    • Print quotes
    • Archive old quotes`"]

    AdminScreens --> AdminPanel["`**⚙️ Admin Panel**
    • User management
    • Add/edit/delete users
    • Role assignments
    • Admin/Sales/Distributor
    • System settings
    • Database tools
    • Import data Excel
    • Export backups
    • Activity logs
    • Error reports
    • Backup controls
    • Email templates
    • Tax rate config
    • Discount rules`"]

    AdminScreens --> Performance["`**📈 Performance Dashboard**
    • User performance metrics
    • Sales by person
    • Quote conversion %
    • Revenue tracking $
    • Top 10 performers
    • Monthly trends
    • Quarterly reports
    • Goal tracking
    • Commission calc
    • Export PDF/Excel
    • Email reports
    • KPI monitoring`"]

    AdminScreens --> UserMgmt["`**👥 User Management**
    • All users list
    • Add new users
    • Edit permissions
    • Enable/disable accounts
    • Reset passwords
    • Activity logs
    • Login history
    • Failed attempts
    • Role changes
    • Last active time
    • Session management
    • Force logout`"]

    AdminScreens --> ErrorMon["`**⚠️ Error Monitor**
    • Error logs viewer
    • Warning alerts
    • Critical errors
    • System status
    • Performance metrics
    • Database health %
    • Storage usage GB
    • API status
    • Response times
    • Fix suggestions
    • Clear resolved
    • Export logs`"]

    Memory --> LoginMem["`**🔐 Login Memory**
    • 30-day remember me
    • Auto-logout 30min idle
    • Multi-device sync
    • Token refresh
    • Session tracking
    • IP logging
    • Device fingerprint`"]

    Memory --> CartMem["`**🛒 Cart Memory**
    • All items saved
    • Quantities preserved
    • Discounts applied
    • Client selected
    • Comments saved
    • Draft quotes
    • Recovery after crash`"]

    Memory --> DataMem["`**📦 Data Memory**
    • 1,098 products cached
    • Filters saved
    • Search history
    • Sort preferences
    • Recently viewed
    • User preferences
    • 100MB cache limit`"]

    Backend --> Firebase["`**🔥 Firebase Services**
    Google Cloud Platform
    Enterprise Grade
    SOC2 Compliant
    GDPR Ready`"]

    Backend --> Database["`**💾 Database Collections**
    NoSQL Structure
    Real-time Sync
    Offline Support
    Auto-backup Daily`"]

    Backend --> Processing["`**🔧 Business Processing**
    Server-side Logic
    Calculations Engine
    Document Generation
    Email Services`"]

    Firebase --> Auth["`**🔐 Authentication**
    • Email/password login
    • 4 role levels
    • Password reset email
    • Account creation
    • Email verification
    • Session management
    • 30-day tokens
    • 2FA ready
    • OAuth ready
    • Multi-device
    • IP tracking
    • Failed attempt lock`"]

    Firebase --> Storage["`**📁 Cloud Storage**
    • 3,534 product images
    • 1,454 thumbnails
    • 2,080 full images
    • CDN distribution
    • 76 edge locations
    • Fast loading
    • Auto-optimization
    • WebP conversion
    • Secure URLs
    • Direct access
    • 1.2GB total size`"]

    Firebase --> Hosting["`**🌐 Web Hosting**
    • taquotes.web.app
    • 99.9% uptime achieved
    • SSL certificates
    • Auto-scaling
    • DDoS protection
    • Global CDN
    • Instant rollback
    • Version history
    • Custom domain
    • Analytics tracking`"]

    Database --> DB_Products["`**📦 Products Database**
    • 1,098 equipment items
    • SKU codes unique
    • Product names
    • Full descriptions
    • List prices $
    • 12 categories
    • Subcategories
    • Image URLs CDN
    • Tech specifications
    • Dimensions W×D×H
    • Weight in lbs
    • Warranty info
    • Model numbers
    • Brand info
    • Min order qty`"]

    Database --> DB_Clients["`**👥 Clients Database**
    • 500+ customers
    • Company names
    • Contact persons
    • Email addresses
    • Phone numbers
    • Billing addresses
    • Shipping addresses
    • Tax ID numbers
    • Credit terms NET30
    • Payment history
    • Notes field
    • Created date
    • Last activity
    • Total purchases
    • Credit limit`"]

    Database --> DB_Quotes["`**📄 Quotes Database**
    • Quote numbers Q2025XXX
    • Creation timestamps
    • Client references
    • Product items array
    • Quantities ordered
    • Unit prices locked
    • Discounts % or $
    • Discount reasons
    • Tax amounts 8%
    • Grand totals
    • Status tracking
    • Comments notes
    • 30-day validity
    • Created by user
    • Version history`"]

    Database --> DB_Warehouses["`**🏭 Warehouses Database**
    16 Global Locations:
    • 999 Reserved (Mexico)
    • CA California (USA)
    • CA1-4 California (USA)
    • COCZ Cool Zone (Mexico)
    • COPZ Parts Zone (Mexico)
    • INT International
    • MEE Mexico Export
    • PU Pick Up
    • SI Special Inventory
    • XCA Export CA
    • XPU Export Pick Up
    • XZRE Export Reserve
    • ZRE Zone Reserve
    Stock levels real-time
    Reorder points set
    Transfer tracking`"]

    Database --> DB_SpareParts["`**🔧 Spare Parts Database**
    • Dynamic components
    • Part numbers SKU
    • Spanish descriptions
    • English descriptions
    • Real-time stock qty
    • Warehouse locations
    • Unit prices $
    • Compatible models
    • Supplier info
    • Lead times days
    • Min order qty
    Categories:
    • Clips filters belts
    • Motors gaskets
    • Sensors switches`"]

    Database --> DB_Users["`**👤 Users Database**
    • User accounts
    • Email logins
    • Full names
    • 4 Role types
    • Permissions matrix
    • Profile info
    • Preferences
    • Activity logs
    • Last login time
    • Created date
    • Encrypted passwords
    • Commission rates
    • Sales targets
    • Manager assignments`"]

    Processing --> PriceCalc["`**🧮 Price Calculator**
    • Line totals: Qty × Price
    • Subtotal: Sum all lines
    • Tax calc: Sub × 8%
    • Discount %: Sub × rate
    • Discount $: Flat amount
    • Reason field required
    • Grand total calculation
    • Currency format $#,###.##
    • Round 2 decimals
    • Multi-currency ready
    • Volume discounts
    • Client discounts`"]

    Processing --> QuoteGen["`**📋 Quote Generator**
    • Auto-number Q2025XXX
    • Sequential numbering
    • Date time stamp
    • Client section complete
    • Product table formatted
    • Calculations displayed
    • Terms conditions
    • 30-day validity
    • Payment terms
    • Signature blocks
    • Company logo
    • Footer text
    • Page numbers
    • Watermark option`"]

    Processing --> EmailSvc["`**📧 Email Service**
    • Gmail SMTP integration
    • PDF attachment auto
    • Excel attachment option
    • 25MB size limit
    • HTML templates
    • Custom messages
    • CC BCC support
    • Delivery tracking
    • Read receipts
    • 3 retry on failure
    • Queue management
    • Bulk sending
    • Schedule delivery`"]

    Processing --> ExportSvc["`**📊 Export Service**
    • Excel generation
    • Multiple sheets
    • Formulas included
    • SUM calculations
    • 10,000 row limit
    • CSV option
    • Formatting preserved
    • Charts possible
    • Bulk export
    • Scheduled exports
    • Email delivery
    • Cloud upload`"]

    classDef frontendStyle fill:#e3f2fd,stroke:#1565c0,stroke-width:3px
    classDef backendStyle fill:#fff3e0,stroke:#ef6c00,stroke-width:3px
    classDef dataStyle fill:#e8f5e9,stroke:#2e7d32,stroke-width:3px
    classDef processStyle fill:#fce4ec,stroke:#c2185b,stroke-width:3px
    classDef adminStyle fill:#ffebee,stroke:#c62828,stroke-width:3px

    class Start,Frontend,UserFlow,Screens,Memory,AuthScreens,MainScreens frontendStyle
    class Backend,Firebase,Auth,Storage,Hosting backendStyle
    class Database,DB_Products,DB_Clients,DB_Quotes,DB_Warehouses,DB_SpareParts,DB_Users dataStyle
    class Processing,PriceCalc,QuoteGen,EmailSvc,ExportSvc processStyle
    class AdminScreens,AdminPanel,Performance,UserMgmt,ErrorMon adminStyle