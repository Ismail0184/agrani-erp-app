# Agrani ERP Mobile App

A Flutter-based ERP and Business Management mobile application designed to connect employees, field teams, sales representatives, warehouse personnel, and management with a centralized ERP system.

The application helps organizations digitize daily operational activities such as attendance, GPS tracking, outlet management, order processing, collections, expenses, delivery operations, warehouse activities, and reporting.

The mobile application communicates with the central ERP backend through REST APIs and provides secure, role-based access to business information.

---

## Overview

Agrani ERP Mobile App was developed to reduce manual business processes and provide employees with a simple mobile interface for performing ERP-related activities from anywhere.

The application is designed for organizations that operate with field sales teams, distribution networks, warehouses, finance teams, and multiple operational departments.

It provides real-time communication between mobile users and the central ERP system while maintaining data accuracy, security, and operational control.

---

## Key Features

### Authentication & User Management

- Secure user login
- Role-based access control
- User-specific menu permissions
- Single-device login management
- Location validation during login
- Automatic attendance integration

### Attendance Management

- Employee attendance from mobile
- First login attendance tracking
- GPS-based attendance information
- Daily attendance status
- Monthly attendance overview

### GPS & Field Force Tracking

- Employee location tracking
- GPS movement monitoring
- Background location updates
- Distance-based location recording
- Offline GPS data storage
- Automatic synchronization when internet connectivity is restored

### Outlet / Customer Management

- View assigned outlets
- Search outlets
- Create new outlets
- Update outlet information
- Capture outlet GPS coordinates
- Upload shop/outlet images
- Route-based outlet management
- Customer outstanding balance visibility

### Sales Order Management

- Create sales orders
- View order history
- Search and filter orders
- Edit eligible orders
- Delete eligible orders
- Outlet-based order creation
- Item/SKU selection
- Quantity and pricing validation
- Order status tracking

### Delivery Management

- Pending delivery list
- Assigned order delivery
- Item-wise delivery quantity
- Partial delivery handling
- Delivery confirmation
- Delivery status tracking
- Order completion workflow

### Collection Management

- Customer collection entry
- Route and outlet-based collection
- Multiple collection channels

Supported collection methods include:

- Cash
- Bank
- Cheque
- Mobile Financial Service
- POS

Additional features include:

- Collection history
- Collection status tracking
- Ledger selection
- Customer balance integration
- Route/outlet persistence for faster entry

### Expense Management

- Mobile expense entry
- Expense voucher creation
- Expense ledger selection
- Vehicle-related expense handling
- Voucher confirmation workflow
- Integration with ERP accounting

### Warehouse & Inventory Operations

- Warehouse-related transactions
- Delivery coordination
- Inventory-related activities
- Item/SKU management
- Integration with ERP inventory records

### Reporting & Dashboard

- Daily operational dashboard
- Order statistics
- Collection statistics
- Attendance information
- User activity information
- ERP data synchronization
- Management visibility

### Offline Support

The application includes offline handling for selected operations.

When network connectivity is unavailable, supported data can be stored locally and synchronized with the ERP server when the connection becomes available again.

---

## Technology Stack

### Mobile Application

- Flutter
- Dart

### Backend Integration

- REST API
- PHP
- MySQL

### Mobile Technologies

- GPS / Geolocation
- Local Database
- Offline Data Synchronization
- Device Permissions
- Image Capture
- Connectivity Monitoring

---

## Flutter Packages

The application uses Flutter packages for functionality such as:

- HTTP communication
- Shared preferences
- SQLite local storage
- Connectivity monitoring
- Geolocation
- Device permissions
- Battery information
- Image picker
- Image cropper
- Maps
- Date and time management
- UUID generation

---

## System Architecture

The application follows a mobile-to-ERP architecture:

```text
┌─────────────────────────────┐
│      Flutter Mobile App     │
│                             │
│ Attendance                  │
│ GPS Tracking                │
│ Orders                      │
│ Collections                 │
│ Expenses                    │
│ Delivery                    │
│ Outlet Management           │
│ Reports                     │
└──────────────┬──────────────┘
               │
               │ HTTPS / REST API
               ▼
┌─────────────────────────────┐
│        ERP REST API         │
│          PHP Backend        │
└──────────────┬──────────────┘
               │
               ▼
┌─────────────────────────────┐
│        MySQL Database       │
│                             │
│ ERP                         │
│ Accounting                  │
│ Sales                       │
│ Inventory                   │
│ Distribution                │
│ HR & Attendance             │
└─────────────────────────────┘
