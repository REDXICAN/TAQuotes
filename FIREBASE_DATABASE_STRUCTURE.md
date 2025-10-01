# Firebase Realtime Database Structure
## TurboAir Quotes (TAQuotes) Application

**Database URL:** `https://taquotes-default-rtdb.firebaseio.com`
**Region:** us-central1
**Type:** DEFAULT_DATABASE

---

## 📊 Root-Level Collections

```
/
├── products/                      # Product catalog (835+ items)
├── spareparts/                    # Spare parts inventory
├── clients/                       # Client data (user-scoped)
│   └── {userId}/
├── quotes/                        # Quote data (user-scoped)
│   └── {userId}/
├── cart_items/                    # Shopping cart (user-scoped)
│   └── {userId}/
├── projects/                      # Projects (user-scoped)
│   └── {userId}/
├── search_history/                # Search history (user-scoped)
│   └── {userId}/
├── users/                         # User metadata
│   └── {userId}/
├── user_profiles/                 # User profile data
│   └── {userId}/
├── user_approval_requests/        # User registration approvals
│   └── {requestId}/
└── .info/                         # Firebase system info
    ├── connected
    └── serverTimeOffset
```

---

## 🔵 **1. Products Collection**
**Path:** `/products/{productId}`

### Structure:
```json
{
  "products": {
    "{productId}": {
      "id": "string",
      "sku": "string",                    // Product SKU (e.g., "M3R19-1-N")
      "model": "string",                  // Model number
      "name": "string",                   // Product name
      "displayName": "string",            // Display name for UI
      "description": "string",            // Product description
      "category": "string",               // Category (Refrigeration, Freezers, etc.)
      "price": number,                    // Base price in USD
      "stock": number,                    // Total stock available
      "totalStock": number,               // Alternative stock field
      "availableStock": number,           // Available stock field
      "warehouse": "string",              // Primary warehouse (999, KR, VN, CN, TX, etc.)

      // Warehouse Stock (per location)
      "warehouseStock": {
        "999": {
          "available": number,
          "reserved": number
        },
        "COCZ": {
          "available": number,
          "reserved": number
        },
        "COPZ": { ... },
        "MEE": { ... },
        "SI": { ... },
        "ZRE": { ... }
      },

      // Images
      "imageUrl": "string",               // P.1 screenshot URL (Firebase Storage)
      "imageUrl2": "string",              // P.2 screenshot URL (Firebase Storage)
      "thumbnailUrl": "string",           // Thumbnail URL (Firebase Storage)
      "image_url": "string",              // Alternative image field

      // Product Specifications
      "specifications": {
        "dimensions": "string",
        "capacity": "string",
        "power": "string",
        "temperature": "string",
        "features": ["string"],
        // ... other specs
      },

      // Metadata
      "createdAt": "ISO8601 timestamp",
      "updatedAt": "ISO8601 timestamp",
      "isSparePart": boolean,             // Flag for spare parts
      "isActive": boolean,                // Active/inactive status
      "productLine": "string"             // Product line classification
    }
  }
}
```

### Key Features:
- **Count:** 835+ products
- **Images:** 3,534 images in Firebase Storage
- **Stock Tracking:** 6 warehouse locations
- **Real-time:** Updates via StreamProvider

---

## 🟢 **2. Spare Parts Collection**
**Path:** `/spareparts/{sparePartId}`

### Structure:
```json
{
  "spareparts": {
    "{sparePartId}": {
      "id": "string",
      "sku": "string",                    // SP-XXX format
      "name": "string",
      "description": "string",
      "category": "string",               // Parts category
      "price": number,
      "stock": number,
      "compatibleWith": ["productId"],    // Compatible product IDs
      "imageUrl": "string",
      "createdAt": "ISO8601 timestamp"
    }
  }
}
```

### Key Features:
- Separate from main products
- Compatibility tracking
- Real-time inventory

---

## 🟡 **3. Clients Collection**
**Path:** `/clients/{userId}/{clientId}`

### Structure:
```json
{
  "clients": {
    "{userId}": {
      "{clientId}": {
        "id": "string",
        "company": "string",              // Company name
        "contactName": "string",          // Contact person
        "email": "string",                // Contact email
        "phone": "string",                // Phone number
        "address": "string",              // Full address
        "city": "string",
        "state": "string",
        "zipCode": "string",
        "country": "string",

        // Additional fields
        "notes": "string",
        "tags": ["string"],               // Client tags
        "isActive": boolean,
        "createdAt": "ISO8601 timestamp",
        "updatedAt": "ISO8601 timestamp",

        // User association
        "userId": "string"                // Owner user ID
      }
    }
  }
}
```

### Access Control:
- **Read:** Only owner (`$uid === auth.uid`)
- **Write:** Only owner (`$uid === auth.uid`)
- **User-scoped:** Each user has separate client list

---

## 🟠 **4. Quotes Collection**
**Path:** `/quotes/{userId}/{quoteId}`

### Structure:
```json
{
  "quotes": {
    "{userId}": {
      "{quoteId}": {
        "id": "string",
        "quoteNumber": "string",          // Format: Q2025XXX
        "status": "string",               // draft, sent, accepted, rejected

        // Client Reference
        "clientId": "string",
        "client": {
          "id": "string",
          "company": "string",
          "contactName": "string",
          "email": "string",
          "phone": "string",
          "address": "string"
        },

        // Quote Items
        "quote_items": [
          {
            "product_id": "string",
            "sku": "string",
            "name": "string",
            "description": "string",
            "quantity": number,
            "unitPrice": number,
            "total": number,
            "imageUrl": "string",
            "category": "string"
          }
        ],

        // Pricing
        "subtotal": number,
        "tax": number,
        "taxRate": number,                // Default: 8%
        "discount": number,
        "discountType": "string",         // "percentage" or "fixed"
        "total": number,
        "totalAmount": number,

        // Comments & Notes
        "comments": "string",
        "internalNotes": "string",

        // Metadata
        "createdAt": "ISO8601 timestamp",
        "updatedAt": "ISO8601 timestamp",
        "validUntil": "ISO8601 timestamp", // 30 days from creation
        "sentAt": "ISO8601 timestamp",
        "acceptedAt": "ISO8601 timestamp",

        // User association
        "userId": "string",

        // Optional project link
        "projectId": "string"
      }
    }
  }
}
```

### Key Features:
- **Count:** 1000+ quotes/month
- **Status Workflow:** draft → sent → accepted/rejected
- **PDF Generation:** Real-time from quote data
- **Email Integration:** Automatic sending

---

## 🔴 **5. Cart Items Collection**
**Path:** `/cart_items/{userId}/{itemId}`

### Structure:
```json
{
  "cart_items": {
    "{userId}": {
      "{itemId}": {
        "productId": "string",
        "sku": "string",
        "name": "string",
        "description": "string",
        "quantity": number,
        "unitPrice": number,
        "total": number,
        "imageUrl": "string",
        "thumbnailUrl": "string",
        "category": "string",
        "isSparePart": boolean,
        "addedAt": "ISO8601 timestamp"
      }
    }
  }
}
```

### Features:
- Real-time sync across devices
- Persistent storage (Hive + Firebase)
- Auto-calculation of totals

---

## 🟣 **6. Projects Collection**
**Path:** `/projects/{userId}/{projectId}`

### Structure:
```json
{
  "projects": {
    "{userId}": {
      "{projectId}": {
        "id": "string",
        "name": "string",                 // Project name
        "description": "string",
        "clientId": "string",             // Associated client
        "status": "string",               // planning, active, completed, cancelled

        // Project details
        "startDate": "ISO8601 timestamp",
        "endDate": "ISO8601 timestamp",
        "budget": number,
        "tags": ["string"],

        // Associated quotes
        "quoteIds": ["string"],

        // Metadata
        "createdAt": "ISO8601 timestamp",
        "updatedAt": "ISO8601 timestamp",
        "userId": "string"
      }
    }
  }
}
```

---

## 🟤 **7. Search History Collection**
**Path:** `/search_history/{userId}/{searchId}`

### Structure:
```json
{
  "search_history": {
    "{userId}": {
      "{searchId}": {
        "query": "string",
        "productId": "string",            // If result was clicked
        "timestamp": "ISO8601 timestamp"
      }
    }
  }
}
```

---

## ⚪ **8. Users Collection**
**Path:** `/users/{userId}`

### Structure:
```json
{
  "users": {
    "{userId}": {
      "uid": "string",
      "email": "string",
      "displayName": "string",
      "role": "string",                   // superadmin, admin, sales, distributor
      "isApproved": boolean,
      "isActive": boolean,
      "createdAt": "ISO8601 timestamp",
      "lastLoginAt": "ISO8601 timestamp",

      // Permissions
      "permissions": {
        "canCreateQuotes": boolean,
        "canManageClients": boolean,
        "canViewReports": boolean,
        "canManageProducts": boolean
      },

      // Metadata
      "phoneNumber": "string",
      "company": "string",
      "photoURL": "string"
    }
  }
}
```

---

## 🔷 **9. User Profiles Collection**
**Path:** `/user_profiles/{userId}`

### Structure:
```json
{
  "user_profiles": {
    "{userId}": {
      "uid": "string",
      "email": "string",
      "displayName": "string",
      "role": "string",
      "isApproved": boolean,
      "isActive": boolean,

      // Profile details
      "firstName": "string",
      "lastName": "string",
      "phoneNumber": "string",
      "company": "string",
      "position": "string",
      "photoURL": "string",

      // Preferences
      "language": "string",               // en, es
      "timezone": "string",
      "currency": "string",               // USD

      // Metadata
      "createdAt": "ISO8601 timestamp",
      "updatedAt": "ISO8601 timestamp",
      "lastLoginAt": "ISO8601 timestamp"
    }
  }
}
```

---

## 🟨 **10. User Approval Requests Collection**
**Path:** `/user_approval_requests/{requestId}`

### Structure:
```json
{
  "user_approval_requests": {
    "{requestId}": {
      "id": "string",
      "userId": "string",
      "email": "string",
      "displayName": "string",
      "requestedRole": "string",
      "company": "string",
      "phoneNumber": "string",
      "message": "string",                // User's message to admin

      // Status
      "status": "string",                 // pending, approved, rejected
      "reviewedBy": "string",             // Admin user ID
      "reviewedAt": "ISO8601 timestamp",
      "reviewNotes": "string",

      // Metadata
      "createdAt": "ISO8601 timestamp",
      "ipAddress": "string",
      "userAgent": "string"
    }
  }
}
```

---

## 🔧 **11. System Collections**

### `.info/connected`
**Path:** `/.info/connected`

```json
{
  ".info": {
    "connected": boolean              // Firebase connection status
  }
}
```

### `.info/serverTimeOffset`
**Path:** `/.info/serverTimeOffset`

```json
{
  ".info": {
    "serverTimeOffset": number        // Milliseconds offset from server
  }
}
```

---

## 🔐 Security Rules Summary

### Products
- **Read:** Public (all authenticated users)
- **Write:** Admin only (`auth.token.email == 'andres@turboairmexico.com'`)

### Clients
- **Read:** Owner only (`$uid === auth.uid`)
- **Write:** Owner only (`$uid === auth.uid`)

### Quotes
- **Read:** Owner only (`$uid === auth.uid`)
- **Write:** Owner only (`$uid === auth.uid`)

### Cart Items
- **Read:** Owner only (`$uid === auth.uid`)
- **Write:** Owner only (`$uid === auth.uid`)

### Projects
- **Read:** Owner only (`$uid === auth.uid`)
- **Write:** Owner only (`$uid === auth.uid`)

### Users/Profiles
- **Read:** Self or admin
- **Write:** Self (limited fields) or admin

### User Approval Requests
- **Read:** Admin or self
- **Write:** User (create), admin (update)

---

## 📊 Data Statistics

| Collection | Records | Scoped By | Real-time |
|------------|---------|-----------|-----------|
| Products | 835+ | Global | ✅ |
| Spare Parts | Dynamic | Global | ✅ |
| Clients | 500+ | User | ✅ |
| Quotes | 1000+/month | User | ✅ |
| Cart Items | Active | User | ✅ |
| Projects | Active | User | ✅ |
| Users | 500+ | Global | ✅ |
| User Profiles | 500+ | Global | ✅ |

---

## 🎯 Query Patterns

### Common Queries

#### Get All Products
```dart
database.ref('products').onValue
```

#### Get User's Clients
```dart
database.ref('clients/$userId').onValue
```

#### Get User's Quotes
```dart
database.ref('quotes/$userId').onValue
```

#### Get User's Cart
```dart
database.ref('cart_items/$userId').onValue
```

#### Get Product by ID
```dart
database.ref('products/$productId').get()
```

#### Filter Quotes by Client
```dart
database.ref('quotes/$userId')
  .orderByChild('clientId')
  .equalTo(clientId)
  .get()
```

#### Filter Products by SKU
```dart
database.ref('products')
  .orderByChild('sku')
  .equalTo(sku)
  .get()
```

#### Filter Products by Model
```dart
database.ref('products')
  .orderByChild('model')
  .equalTo(model)
  .get()
```

---

## 🔄 Real-time Listeners

### Connection Monitoring
```dart
database.ref('.info/connected').onValue.listen((event) {
  final connected = event.snapshot.value as bool;
  // Handle connection state
});
```

### Keep Synced (Offline Support)
```dart
database.ref('products').keepSynced(true);
database.ref('cart_items/$userId').keepSynced(true);
```

---

## 💾 Storage Limits

- **Simultaneous Connections:** 100,000
- **Bandwidth:** 10 GB/month (Blaze plan)
- **Storage:** 1 GB
- **Download:** 10 GB/month
- **Max Payload:** 256 MB
- **URL Length:** 2048 characters

---

## 📝 Naming Conventions

### Collections
- Use lowercase with underscores: `cart_items`, `user_profiles`
- Plural form for collections

### Fields
- camelCase: `displayName`, `createdAt`
- Timestamps: ISO 8601 format
- Booleans: Prefix with `is` or `has`: `isActive`, `hasStock`

### IDs
- Firebase auto-generated push IDs
- Format: `-NXxxxxxxxxxxxx` (20 characters)

---

## 🔗 Relationships

```
User (1) ────── (Many) Clients
User (1) ────── (Many) Quotes
User (1) ────── (Many) Projects
User (1) ────── (Many) Cart Items

Client (1) ──── (Many) Quotes
Client (1) ──── (Many) Projects

Project (1) ─── (Many) Quotes

Quote (Many) ── (Many) Products (through quote_items)
Cart (Many) ─── (Many) Products
```

---

## 📌 Important Notes

1. **No Cascading Deletes:** Manual cleanup required
2. **Denormalized Data:** Client info duplicated in quotes for performance
3. **User-Scoped Collections:** Data isolated per user for security
4. **Firebase Storage URLs:** Images stored separately, URLs in database
5. **Real-time Updates:** All collections support live listeners
6. **Offline Support:** Critical collections use `keepSynced(true)`

---

**Last Updated:** October 1, 2025
**Database Version:** Production (v1.0)
**Total Collections:** 11
**Total Records:** ~3,000+

