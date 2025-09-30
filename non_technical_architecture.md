# TurboAir Quotes - Non-Technical Architecture Diagram

## Complete System Overview for Business Stakeholders

```mermaid
graph TB
    subgraph "🎨 FRONTEND (Client-Side) - Complete Non-Technical Version"
        subgraph "👤 USER JOURNEY MAP"
            subgraph "User Actions"
                U1[Visit Website<br/>━━━━━<br/>Open taquotes.web.app<br/>Works on any browser<br/>No download needed]
                U2[Enter Credentials<br/>━━━━━<br/>Email and password<br/>Stay logged in 30 days<br/>Forgot password option]
                U3[Browse Products<br/>━━━━━<br/>835 products available<br/>Filter by category<br/>Search by name/SKU]
                U4[Add to Cart<br/>━━━━━<br/>Select quantity<br/>See running total<br/>Cart saves automatically]
                U5[Select Client<br/>━━━━━<br/>Choose from 500+ clients<br/>Or add new client<br/>Search by name/company]
                U6[Generate Quote<br/>━━━━━<br/>Auto-numbered quotes<br/>Professional PDF format<br/>Digital signature ready]
                U7[Send Email<br/>━━━━━<br/>Attach PDF and Excel<br/>Custom message<br/>Delivery tracking]
            end

            subgraph "📱 UI SCREENS - All Features"
                I1[🔐 Login Screen<br/>━━━━━<br/>📱 Entry Point<br/>Email/password login<br/>Remember me checkbox<br/>Forgot password link<br/>Register new account<br/>Error messages<br/>Loading spinner]

                I2[🏠 Home Dashboard<br/>━━━━━<br/>📱 Command Center<br/>Total products count<br/>Active clients count<br/>Monthly quotes count<br/>Cart items badge<br/>Quick action buttons<br/>Recent activity feed<br/>Performance metrics<br/>Welcome message]

                I3[📦 Product Catalog<br/>━━━━━<br/>📱 Equipment Browser<br/>835 products total<br/>Category tabs<br/>Search bar<br/>Price display with commas<br/>Thumbnail images<br/>Add to cart buttons<br/>Stock availability indicators<br/>Load more on scroll<br/>Sort by price/name/SKU]

                I4[🛒 Shopping Cart<br/>━━━━━<br/>📱 Quote Builder<br/>Line items with quantities<br/>Individual prices per unit<br/>Line total calculations<br/>Remove item buttons<br/>Quantity adjusters<br/>Subtotal calculation<br/>Tax calculation 8 percent<br/>Discount field percent or dollar<br/>Discount reason notes<br/>Grand total calculations<br/>Client selector dropdown<br/>Comments section collapsible<br/>Save draft option<br/>Generate quote button<br/>Clear cart option]

                I5[👥 Client Selector<br/>━━━━━<br/>📱 Customer Picker<br/>Search by company name<br/>Search by contact name<br/>Search by email<br/>Search by phone<br/>Add new client button<br/>Edit client info<br/>Client details preview<br/>Recently used clients<br/>Favorite clients]

                I6[📋 Quote Builder<br/>━━━━━<br/>📱 Professional Quotes<br/>Quote number TAQ format<br/>Date generated<br/>Client full information<br/>Itemized products list<br/>Quantities and unit prices<br/>Line totals<br/>Subtotal amount<br/>Tax amount 8 percent<br/>Discount applied<br/>Grand total due<br/>Terms and conditions<br/>Digital signature space<br/>Company logo TurboAir<br/>30-day validity period<br/>Payment terms]

                I7[✅ Success Modal<br/>━━━━━<br/>📱 Confirmation<br/>Quote sent message<br/>Email recipient shown<br/>Quote number display<br/>View quote button<br/>Send another button<br/>Download PDF option<br/>Share link option<br/>Print option]

                I8[🔍 Product Detail<br/>━━━━━<br/>📱 Full Specifications<br/>Multiple product images P.1 P.2<br/>Image zoom capability<br/>Technical specifications<br/>Dimensions and weight<br/>Available accessories<br/>Related products<br/>Stock by 16 warehouses<br/>Add to cart with quantity<br/>Request more info button<br/>Download spec sheet]

                I9[👥 Clients Screen<br/>━━━━━<br/>📱 Customer Database<br/>Client list table<br/>Company names<br/>Contact persons<br/>Email addresses<br/>Phone numbers<br/>Physical addresses<br/>Tax ID numbers<br/>Add new client form<br/>Edit existing clients<br/>Delete clients with confirm<br/>Import from Excel<br/>Export to Excel<br/>Search and filter box<br/>Sort by name/date/value]

                I10[📊 Stock Dashboard<br/>━━━━━<br/>📱 Inventory Monitor<br/>16 warehouse locations<br/>999 CA CA1 CA2 CA3 CA4<br/>COCZ COPZ INT MEE<br/>PU SI XCA XPU XZRE ZRE<br/>Stock levels per location<br/>Low stock alerts red<br/>Medium stock yellow<br/>Good stock green<br/>Category breakdown chart<br/>Total inventory value<br/>Reorder suggestions<br/>Stock movement history<br/>Warehouse comparison table]

                I11[🔧 Spare Parts<br/>━━━━━<br/>📱 Parts Catalog<br/>94 spare parts total<br/>Part numbers SKU<br/>Part descriptions<br/>Stock quantities 1716 units<br/>Warehouse locations<br/>Price per unit<br/>Add to quote button<br/>Category filters<br/>Compatibility info<br/>Supplier details]

                I12[📄 Quotes Screen<br/>━━━━━<br/>📱 Quote History<br/>All quotes list table<br/>Quote numbers TAQ format<br/>Creation dates<br/>Client names<br/>Total amounts with currency<br/>Status badges Draft/Sent/Viewed<br/>Search quotes box<br/>Filter by date range<br/>Filter by client<br/>Filter by status<br/>View details button<br/>Duplicate quote option<br/>Edit draft quotes<br/>Delete quotes with confirm<br/>Export to Excel<br/>Bulk PDF export<br/>Email quote again]

                I13[👤 Profile Screen<br/>━━━━━<br/>📱 User Settings<br/>Personal information<br/>Name and title<br/>Change password<br/>Profile picture upload<br/>Email preferences<br/>Language selection EN/ES<br/>Time zone setting<br/>Signature upload<br/>Sales targets<br/>Commission tracking]

                I14[⚙️ Settings Screen<br/>━━━━━<br/>📱 App Configuration<br/>Theme Light/Dark mode<br/>Currency format<br/>Tax rate settings 8 percent<br/>Default discount rates<br/>Email templates editor<br/>Backup settings schedule<br/>Export preferences<br/>Printer settings<br/>Notification preferences<br/>Auto-save intervals]

                I15[💾 Backup Management<br/>━━━━━<br/>📱 Data Safety<br/>Manual backup now<br/>Auto-backup schedule daily<br/>Restore from backup<br/>Export all data to Excel<br/>Backup history list<br/>Storage location cloud<br/>Retention period 30 days<br/>Download backup file]

                I16[⚙️ Admin Panel<br/>━━━━━<br/>📱 System Control<br/>User management<br/>Role assignments 4 levels<br/>System settings<br/>Database tools<br/>Import/export data<br/>Activity logs viewer<br/>Error reports<br/>Backup controls<br/>Admin email access]

                I17[📈 Performance Dashboard<br/>━━━━━<br/>📱 Analytics Center<br/>User performance metrics<br/>Sales metrics by person<br/>Quote conversion rates<br/>Revenue tracking<br/>Top 10 performers<br/>Monthly trends graphs<br/>Goal tracking progress<br/>Export reports<br/>Commission calculations]

                I18[👥 User Management<br/>━━━━━<br/>📱 Team Control<br/>View all users list<br/>Add new users form<br/>Edit permissions checkboxes<br/>Disable/enable accounts<br/>Reset passwords<br/>Activity tracking logs<br/>Login history table<br/>Role changes 4 types<br/>Last active timestamps]

                I19[⚠️ Error Monitor<br/>━━━━━<br/>📱 System Health<br/>Error logs viewer<br/>Warning alerts yellow<br/>Critical alerts red<br/>System status indicators<br/>Performance metrics<br/>Database health percent<br/>Storage usage GB<br/>API status indicators<br/>Fix suggestions<br/>Clear resolved errors]

                I20[🗄️ Database Management<br/>━━━━━<br/>📱 Data Control<br/>View 6 collections<br/>Edit records inline<br/>Delete data with confirm<br/>Import Excel 10k limit<br/>Export backups JSON<br/>Data validation checks<br/>Cleanup duplicate tools<br/>Migration tools<br/>Populate demo data]
            end

            subgraph "⚡ STATE LAYER - How App Remembers"
                S1[🔐 Login State<br/>━━━━━<br/>🎯 Authentication Memory<br/>Keeps you logged in<br/>30-day remember me<br/>Auto-logout after 30min idle<br/>Token refresh automatic<br/>Session tracking<br/>Multiple device support]

                S2[📦 Product State<br/>━━━━━<br/>🎯 Catalog Memory<br/>835 products loaded<br/>Search results saved<br/>Filter selections kept<br/>Sort preferences<br/>Recently viewed items<br/>Category selection]

                S3[🛒 Cart State<br/>━━━━━<br/>🎯 Order Memory<br/>Current items list<br/>Quantities for each<br/>Discounts applied<br/>Tax calculations 8 percent<br/>Selected client info<br/>Comments saved<br/>Draft quotes stored<br/>Subtotal/total amounts]

                S4[👥 Client State<br/>━━━━━<br/>🎯 Customer Memory<br/>Client list cached<br/>Selected client highlighted<br/>Recent clients last 10<br/>Search results<br/>New client forms<br/>Edit history]

                S5[📊 Stock State<br/>━━━━━<br/>🎯 Inventory Memory<br/>Real-time levels<br/>16 warehouse data<br/>Low stock alerts<br/>Reorder points set<br/>Stock movements log<br/>Last update time]

                S6[📄 Quote State<br/>━━━━━<br/>🎯 Quote Memory<br/>Quote history all<br/>Current quote draft<br/>Draft quotes list<br/>Quote templates<br/>Numbering sequence<br/>Filter preferences]
            end
        end
    end

    subgraph "⚙️ BACKEND (Server-Side) - Complete Non-Technical Version"
        subgraph "🔥 FIREBASE SERVICES - Google Cloud Platform"
            B1[🔐 User Authentication<br/>━━━━━<br/>☁️ Login System<br/>Secure password storage<br/>Email verification sent<br/>Password reset emails<br/>New account creation<br/>4 role levels management<br/>Session control 30 min<br/>Two-factor auth ready<br/>Login from multiple devices]

            B2[💾 Live Database<br/>━━━━━<br/>☁️ Real-time Storage<br/>Instant updates<br/>Real-time sync all devices<br/>Works offline 100MB<br/>Auto-save everything<br/>Conflict resolution<br/>Data validation rules<br/>Automatic backups<br/>Version history]

            B3[📁 File Storage<br/>━━━━━<br/>☁️ Image Server CDN<br/>3534 product images total<br/>1454 thumbnails small<br/>2080 full images<br/>Fast loading worldwide<br/>Global delivery CDN<br/>Auto-optimization<br/>Secure access control<br/>Direct URL access]

            B4[⚡ Background Tasks<br/>━━━━━<br/>☁️ Automation Engine<br/>Email sending queue<br/>PDF generation service<br/>Excel file creation<br/>Data processing jobs<br/>Scheduled tasks cron<br/>Error handling retry<br/>Queue management<br/>Performance monitoring]

            B5[🌐 Web Hosting<br/>━━━━━<br/>☁️ Website Server<br/>URL taquotes.web.app<br/>Always online 99.95 percent<br/>Fast loading 2 sec<br/>Global access CDN<br/>SSL security HTTPS<br/>Auto-scaling traffic<br/>DDoS protection<br/>Automatic updates]
        end

        subgraph "📧 EXTERNAL SERVICES - Third Party"
            E1[📧 Gmail Email Service<br/>━━━━━<br/>🌐 Email Integration<br/>Quote PDF delivery<br/>Excel attachments<br/>HTML formatted emails<br/>Custom templates<br/>Delivery tracking<br/>3 retry on failure<br/>25MB attachment limit<br/>CC/BCC support<br/>Read receipts]

            E2[📄 PDF Generator<br/>━━━━━<br/>🌐 Document Creator<br/>Professional layout design<br/>TurboAir logo branding<br/>Itemized product lists<br/>All calculations shown<br/>Terms and conditions<br/>Digital signature space<br/>Watermarks optional<br/>Page numbers<br/>Custom fonts]

            E3[📊 Excel Export<br/>━━━━━<br/>🌐 Spreadsheet Maker<br/>Quote details export<br/>Product lists with prices<br/>Client database export<br/>Formulas included SUM<br/>Multiple sheets tabs<br/>Formatting preserved<br/>Charts possible<br/>Bulk export 10k rows<br/>CSV option available]
        end

        subgraph "💾 DATA COLLECTIONS - Database Structure"
            DB1[📦 Products Database<br/>━━━━━<br/>📊 835 Equipment Items<br/>SKU codes unique<br/>Product names<br/>Descriptions full<br/>List prices dollars<br/>Categories<br/>Subcategories<br/>Image URLs CDN<br/>Technical specifications<br/>Dimensions<br/>Weight lbs<br/>Warranty info<br/>Model numbers]

            DB2[👥 Clients Database<br/>━━━━━<br/>📊 500+ Customers<br/>Company names<br/>Contact person names<br/>Email addresses<br/>Phone numbers<br/>Billing addresses<br/>Shipping addresses<br/>Tax ID numbers<br/>Credit terms NET 30<br/>Notes field<br/>Created date<br/>Last activity<br/>Total purchases]

            DB3[📄 Quotes Database<br/>━━━━━<br/>📊 Sales Records History<br/>Quote numbers TAQ format<br/>Creation dates and times<br/>Client information<br/>Product items array<br/>Quantities for each<br/>Unit prices<br/>Discounts applied<br/>Discount reasons<br/>Tax amounts 8 percent<br/>Grand total amounts<br/>Status Draft/Sent/Viewed<br/>Comments/notes<br/>30-day validity<br/>Created by user]

            DB4[🏭 Warehouses Database<br/>━━━━━<br/>📊 16 Global Locations<br/>999 Main warehouse<br/>CA California<br/>CA1 CA2 CA3 CA4 Sub<br/>COCZ Costa Rica<br/>COPZ Colombia<br/>INT International<br/>MEE Mexico East<br/>PU Puebla<br/>SI Sinaloa<br/>XCA Export CA<br/>XPU Export PU<br/>XZRE Export Zone<br/>ZRE Zone Reserve<br/>Stock levels each<br/>Reorder points]

            DB5[🔧 Spare Parts Database<br/>━━━━━<br/>📊 94 Components<br/>Part numbers SKU<br/>Descriptions Spanish/English<br/>Stock quantities 1716 total<br/>Warehouse locations<br/>Unit prices dollars<br/>Compatible models list<br/>Supplier information<br/>Lead times days<br/>Min order quantity<br/>Category clips filters etc]

            DB6[👤 Users Database<br/>━━━━━<br/>📊 Team Members<br/>Email addresses login<br/>Full names<br/>Roles 4 types<br/>Permissions matrix<br/>Profile information<br/>Preferences saved<br/>Activity logs<br/>Last login time<br/>Created date<br/>Password encrypted<br/>Commission rate percent]
        end

        subgraph "🔧 BUSINESS SERVICES - Processing Engine"
            BS1[🧮 Price Calculator<br/>━━━━━<br/>💼 Math Engine<br/>Line totals qty times price<br/>Subtotals sum<br/>Tax calculation 8 percent default<br/>Percentage discounts<br/>Dollar discounts<br/>Discount reasons field<br/>Grand totals<br/>Currency format<br/>Rounding rules 2 decimals<br/>Multi-currency ready]

            BS2[📋 Quote Generator<br/>━━━━━<br/>💼 Document Builder<br/>Auto-numbering TAQ format<br/>Date/time stamping<br/>Client details section<br/>Product tables formatted<br/>Price breakdowns clear<br/>Terms and conditions<br/>30-day validity<br/>Footer text custom<br/>Signature blocks<br/>Page breaks smart]

            BS3[🔍 Search Engine<br/>━━━━━<br/>💼 Find System<br/>Product search name/SKU<br/>Client search all fields<br/>Quote search number/client<br/>SKU lookup exact<br/>Partial matching fuzzy<br/>Filter options multiple<br/>Sort results A-Z price<br/>Recent searches saved<br/>Quick filters<br/>Advanced search]

            BS4[📦 Stock Manager<br/>━━━━━<br/>💼 Inventory Control<br/>Track levels real-time<br/>Update counts instant<br/>Low stock alerts red<br/>Reorder suggestions smart<br/>Movement history log<br/>Warehouse transfers<br/>Reserve stock quotes<br/>Available stock free<br/>Stock forecasting<br/>ABC analysis]
        end
    end

    U1 --> I1
    U2 --> I2
    U3 --> I3
    U4 --> I4
    U5 --> I5
    U6 --> I6
    U7 --> I7

    I1 --> S1
    I3 --> S2
    I4 --> S3
    I9 --> S4
    I10 --> S5
    I12 --> S6

    S1 --> B1
    S2 --> B2
    S3 --> B2
    S4 --> B2
    S5 --> B2
    S6 --> B2

    I4 --> BS1
    I6 --> BS2
    I3 --> BS3
    I10 --> BS4

    BS2 --> E2
    I6 --> E1
    I12 --> E3

    B2 --> DB1
    B2 --> DB2
    B2 --> DB3
    B2 --> DB4
    B2 --> DB5
    B2 --> DB6

    B3 --> I3
    B3 --> I8

    classDef loginStyle fill:#e3f2fd,stroke:#1565c0,stroke-width:3px
    classDef cartStyle fill:#fce4ec,stroke:#c2185b,stroke-width:3px
    classDef productStyle fill:#fff3e0,stroke:#ef6c00,stroke-width:3px
    classDef clientStyle fill:#f3e5f5,stroke:#6a1b9a,stroke-width:3px
    classDef quoteStyle fill:#e0f2f1,stroke:#00796b,stroke-width:3px
    classDef stockStyle fill:#e8f5e9,stroke:#2e7d32,stroke-width:3px
    classDef adminStyle fill:#ffebee,stroke:#c62828,stroke-width:3px
    classDef firebaseStyle fill:#fff8e1,stroke:#f9a825,stroke-width:3px
    classDef stateStyle fill:#f1f8e9,stroke:#689f38,stroke-width:3px
    classDef serviceStyle fill:#e1f5fe,stroke:#01579b,stroke-width:3px

    class I1,U1,U2,S1 loginStyle
    class I4,S3,BS1 cartStyle
    class I3,I8,S2,DB1,BS3 productStyle
    class I5,I9,S4,DB2 clientStyle
    class I6,I7,I12,S6,DB3,BS2 quoteStyle
    class I10,I11,S5,DB4,DB5,BS4 stockStyle
    class I16,I17,I18,I19,I20 adminStyle
    class B1,B2,B3,B4,B5 firebaseStyle
    class S1,S2,S3,S4,S5,S6 stateStyle
    class E1,E2,E3,BS1,BS2,BS3,BS4 serviceStyle
```

## Key System Features

- **835 Products** with complete specifications
- **500+ Clients** database management
- **94 Spare Parts** inventory tracking
- **16 Warehouses** globally distributed
- **3,534 Product Images** in cloud storage
- **Real-time Updates** across all devices
- **Offline Mode** with 100MB cache
- **4 User Role Levels** for access control
- **30-day Login Memory** for convenience
- **8% Tax Calculation** with discounts
- **Professional PDF Quotes** with branding
- **Email Integration** with attachments