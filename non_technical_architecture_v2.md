# TurboAir Quotes - Non-Technical Architecture (Improved Layout)

## System Overview - Hierarchical View

```mermaid
graph TD
    Start[🌐 TurboAir Quotes System<br/>━━━━━━━━━<br/>Web App: taquotes.web.app<br/>835 Products • 500+ Clients<br/>94 Spare Parts • 16 Warehouses]

    Start --> Frontend[🎨 FRONTEND<br/>━━━━━━━━━<br/>What Users See<br/>Runs in Browser/Device]
    Start --> Backend[⚙️ BACKEND<br/>━━━━━━━━━<br/>Behind the Scenes<br/>Runs in Cloud]

    %% Frontend Branch
    Frontend --> UserFlow[👤 User Flow]
    Frontend --> Screens[📱 App Screens]
    Frontend --> Memory[💾 App Memory]

    %% User Flow Details
    UserFlow --> UF1[1️⃣ Visit Website<br/>taquotes.web.app]
    UserFlow --> UF2[2️⃣ Login with Email<br/>Stay logged 30 days]
    UserFlow --> UF3[3️⃣ Browse Products<br/>835 items available]
    UserFlow --> UF4[4️⃣ Add to Cart<br/>Build your quote]
    UserFlow --> UF5[5️⃣ Select Client<br/>500+ customers]
    UserFlow --> UF6[6️⃣ Generate Quote<br/>Professional PDF]
    UserFlow --> UF7[7️⃣ Send Email<br/>With attachments]

    %% Screens Branch
    Screens --> AuthScreens[🔐 Login Screens]
    Screens --> MainScreens[📊 Main Features]
    Screens --> AdminScreens[🛡️ Admin Only]

    AuthScreens --> Login[Login Screen<br/>• Email/Password<br/>• Remember Me<br/>• Forgot Password]
    AuthScreens --> Register[Register Screen<br/>• New Account<br/>• Email Verify<br/>• Role Selection]

    MainScreens --> Home[🏠 Home<br/>• Dashboard<br/>• Metrics<br/>• Quick Actions]
    MainScreens --> Products[📦 Products<br/>• 835 Items<br/>• Categories<br/>• Search/Filter]
    MainScreens --> Cart[🛒 Cart<br/>• Line Items<br/>• Discounts %/$<br/>• Tax 8%<br/>• Grand Total]
    MainScreens --> Clients[👥 Clients<br/>• 500+ Records<br/>• Add/Edit/Delete<br/>• Import/Export]
    MainScreens --> Stock[📊 Stock<br/>• 16 Warehouses<br/>• Real-time Levels<br/>• Alerts]

    AdminScreens --> AdminPanel[Admin Panel<br/>• User Management<br/>• System Settings<br/>• Database Tools]
    AdminScreens --> Performance[Performance<br/>• Sales Metrics<br/>• Conversion Rates<br/>• Reports]

    %% Memory Branch
    Memory --> LoginMem[🔐 Login Memory<br/>• 30-day Remember<br/>• Auto-logout 30min<br/>• Multi-device]
    Memory --> CartMem[🛒 Cart Memory<br/>• Items & Quantities<br/>• Discounts Applied<br/>• Client Selected]
    Memory --> DataMem[📦 Data Memory<br/>• Products Loaded<br/>• Filters Saved<br/>• Search History]

    %% Backend Branch
    Backend --> Firebase[🔥 Firebase Services]
    Backend --> Database[💾 Database]
    Backend --> Processing[🔧 Processing]

    Firebase --> Auth[🔐 Authentication<br/>• Login System<br/>• 4 Role Levels<br/>• Password Reset]
    Firebase --> Storage[📁 Cloud Storage<br/>• 3,534 Images<br/>• CDN Delivery<br/>• Fast Loading]
    Firebase --> Hosting[🌐 Web Hosting<br/>• 99.95% Uptime<br/>• SSL Security<br/>• Auto-scaling]

    Database --> DB_Products[📦 Products DB<br/>• 835 Items<br/>• SKUs & Prices<br/>• Specifications]
    Database --> DB_Clients[👥 Clients DB<br/>• 500+ Customers<br/>• Contact Info<br/>• Credit Terms]
    Database --> DB_Warehouses[🏭 Warehouses DB<br/>• 16 Locations:<br/>999, CA, CA1-4<br/>COCZ, COPZ, INT<br/>MEE, PU, SI<br/>XCA, XPU, XZRE, ZRE]
    Database --> DB_SpareParts[🔧 Spare Parts DB<br/>• 94 Components<br/>• 1,716 Units Total<br/>• Stock by Location]

    Processing --> PriceCalc[🧮 Price Calculator<br/>• Qty × Price<br/>• Tax 8%<br/>• Discounts %/$]
    Processing --> QuoteGen[📋 Quote Generator<br/>• TAQ-2025-001<br/>• PDF Creation<br/>• Digital Signature]
    Processing --> EmailSvc[📧 Email Service<br/>• Gmail SMTP<br/>• PDF Attachment<br/>• 25MB Limit]

    classDef frontendStyle fill:#e3f2fd,stroke:#1565c0,stroke-width:3px
    classDef backendStyle fill:#fff3e0,stroke:#ef6c00,stroke-width:3px
    classDef dataStyle fill:#e8f5e9,stroke:#2e7d32,stroke-width:3px
    classDef processStyle fill:#fce4ec,stroke:#c2185b,stroke-width:3px

    class Start,Frontend,UserFlow,Screens,Memory,AuthScreens,MainScreens,AdminScreens frontendStyle
    class Backend,Firebase,Auth,Storage,Hosting backendStyle
    class Database,DB_Products,DB_Clients,DB_Warehouses,DB_SpareParts dataStyle
    class Processing,PriceCalc,QuoteGen,EmailSvc processStyle
```

## Feature Details - Tabular Organization

```mermaid
graph LR
    subgraph "📱 SCREEN FEATURES"
        subgraph "Shopping Cart Complete Features"
            Cart_Features[🛒 SHOPPING CART<br/>━━━━━━━━━<br/>ALL FEATURES]
            Cart_Features --> Cart_Items[📦 Line Items<br/>• Product Name<br/>• SKU Number<br/>• Quantity Selector<br/>• Unit Price<br/>• Line Total]
            Cart_Features --> Cart_Calc[🧮 Calculations<br/>• Subtotal Sum<br/>• Tax 8% Default<br/>• Discount Percent<br/>• Discount Dollar<br/>• Grand Total]
            Cart_Features --> Cart_Actions[⚡ Actions<br/>• Add/Remove Items<br/>• Update Quantities<br/>• Apply Discounts<br/>• Add Reason Notes<br/>• Clear Cart]
            Cart_Features --> Cart_Client[👥 Client Section<br/>• Select Customer<br/>• View Details<br/>• Add New Client<br/>• Search Clients<br/>• Recent Clients]
            Cart_Features --> Cart_Output[📄 Output<br/>• Save Draft<br/>• Generate Quote<br/>• Preview PDF<br/>• Send Email<br/>• Print Quote]
        end

        subgraph "Stock Dashboard Complete"
            Stock_Features[📊 STOCK DASHBOARD<br/>━━━━━━━━━<br/>16 WAREHOUSES]
            Stock_Features --> Stock_Locations[🏭 Locations<br/>999 Main<br/>CA California<br/>CA1 CA2 CA3 CA4<br/>COCZ Costa Rica<br/>COPZ Colombia]
            Stock_Features --> Stock_More[🏭 More Locations<br/>INT International<br/>MEE Mexico East<br/>PU Puebla<br/>SI Sinaloa<br/>XCA XPU XZRE ZRE]
            Stock_Features --> Stock_Display[📊 Display<br/>• Real-time Levels<br/>• Color Alerts<br/>• Pie Charts<br/>• Comparisons<br/>• History]
            Stock_Features --> Stock_Alerts[🚨 Alerts<br/>• Low Stock Red<br/>• Medium Yellow<br/>• Good Green<br/>• Reorder Points<br/>• Suggestions]
        end

        subgraph "Spare Parts System"
            Spare_Features[🔧 SPARE PARTS<br/>━━━━━━━━━<br/>94 COMPONENTS]
            Spare_Features --> Spare_Data[📊 Data<br/>• Part Numbers<br/>• Descriptions<br/>• 1,716 Units Total<br/>• Warehouse Stock<br/>• Prices]
            Spare_Features --> Spare_Categories[📁 Categories<br/>• Clips<br/>• Filters<br/>• Belts<br/>• Motors<br/>• Gaskets]
            Spare_Features --> Spare_Actions[⚡ Actions<br/>• Add to Quote<br/>• Check Stock<br/>• View Details<br/>• Filter/Search<br/>• Export List]
        end
    end

    subgraph "🔧 BUSINESS LOGIC"
        subgraph "Price Calculations"
            Price_Logic[💰 PRICING ENGINE<br/>━━━━━━━━━<br/>CALCULATIONS]
            Price_Logic --> Price_Line[Line Totals<br/>Qty × Price]
            Price_Logic --> Price_Sub[Subtotal<br/>Sum All Lines]
            Price_Logic --> Price_Tax[Tax Calculation<br/>Subtotal × 8%]
            Price_Logic --> Price_Disc[Discounts<br/>Percent or Dollar<br/>With Reason Field]
            Price_Logic --> Price_Total[Grand Total<br/>Sub + Tax - Discount]
        end

        subgraph "Quote Generation"
            Quote_Logic[📋 QUOTE SYSTEM<br/>━━━━━━━━━<br/>GENERATION]
            Quote_Logic --> Quote_Num[Numbering<br/>TAQ-2025-001<br/>Auto-increment]
            Quote_Logic --> Quote_Content[Content<br/>• Client Info<br/>• Product List<br/>• Calculations<br/>• Terms]
            Quote_Logic --> Quote_Format[Format<br/>• PDF Layout<br/>• Company Logo<br/>• Signature Space<br/>• 30-day Valid]
        end
    end

    classDef cartStyle fill:#fce4ec,stroke:#c2185b,stroke-width:3px
    classDef stockStyle fill:#e8f5e9,stroke:#2e7d32,stroke-width:3px
    classDef spareStyle fill:#f3e5f5,stroke:#6a1b9a,stroke-width:3px
    classDef priceStyle fill:#fff3e0,stroke:#ef6c00,stroke-width:3px
    classDef quoteStyle fill:#e0f2f1,stroke:#00796b,stroke-width:3px

    class Cart_Features,Cart_Items,Cart_Calc,Cart_Actions,Cart_Client,Cart_Output cartStyle
    class Stock_Features,Stock_Locations,Stock_More,Stock_Display,Stock_Alerts stockStyle
    class Spare_Features,Spare_Data,Spare_Categories,Spare_Actions spareStyle
    class Price_Logic,Price_Line,Price_Sub,Price_Tax,Price_Disc,Price_Total priceStyle
    class Quote_Logic,Quote_Num,Quote_Content,Quote_Format quoteStyle
```

## User Journey - Sequential Flow

```mermaid
sequenceDiagram
    participant U as User
    participant W as Website
    participant DB as Database
    participant E as Email

    U->>W: 1. Visit taquotes.web.app
    W-->>U: Show Login Screen

    U->>W: 2. Enter Email/Password
    W->>DB: Verify Credentials
    DB-->>W: Authentication OK
    W-->>U: Show Home Dashboard

    U->>W: 3. Browse Products (835 items)
    W->>DB: Load Products
    DB-->>W: Product Data
    W-->>U: Display Catalog

    U->>W: 4. Add Items to Cart
    W-->>U: Update Cart (with calculations)
    Note over W: Subtotal = Sum(Qty × Price)<br/>Tax = Subtotal × 8%<br/>Discount = % or $<br/>Total = Subtotal + Tax - Discount

    U->>W: 5. Select Client (500+ available)
    W->>DB: Load Clients
    DB-->>W: Client List
    W-->>U: Show Client Dropdown

    U->>W: 6. Generate Quote
    W->>W: Create PDF (TAQ-2025-001)
    W-->>U: Show Quote Preview

    U->>W: 7. Send Quote
    W->>E: Send Email with PDF
    E-->>E: Add to Queue
    E-->>U: Delivery Confirmation
```

## System Metrics Dashboard

```mermaid
pie title "System Components Distribution"
    "Products (835)" : 835
    "Clients (500+)" : 500
    "Spare Parts (94)" : 94
    "Warehouses (16)" : 16
    "Images (3534)" : 100
```

```mermaid
pie title "Warehouse Distribution"
    "999 Main" : 25
    "CA Group (5)" : 20
    "Mexico (MEE, PU, SI)" : 15
    "International (INT)" : 10
    "Central America (COCZ, COPZ)" : 15
    "Export (XCA, XPU, XZRE, ZRE)" : 15
```

## Key Features Summary

| Category | Details |
|----------|---------|
| **🛒 Cart Features** | Line items, Quantities, Prices, Discounts (% and $), Tax (8%), Client selection, Comments, Draft save |
| **📊 Stock System** | 16 warehouses (999, CA, CA1-4, COCZ, COPZ, INT, MEE, PU, SI, XCA, XPU, XZRE, ZRE), Real-time levels, Color alerts |
| **🔧 Spare Parts** | 94 components, 1,716 total units, Category filters, Stock by warehouse |
| **💰 Calculations** | Line totals (Qty × Price), Subtotal, Tax (8%), Discounts (% or $), Discount reasons, Grand total |
| **📄 Quote System** | Auto-numbering (TAQ-2025-XXX), PDF generation, Digital signature, 30-day validity, Email delivery |
| **👤 User Features** | 30-day login memory, 30-min idle timeout, 4 role levels, Multi-device support |
| **📱 Performance** | 99.95% uptime, 2-second load time, 100MB offline cache, Real-time sync |