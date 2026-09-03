# G9 POS
<!-- one page that states the project in a paragraph and links out to every other doc, rather than restating architecture -->

> **This page is a summary, not a source of truth.** The sections below restate material owned by other documents. Where they disagree, the specification wins: `API-SPEC.md` for endpoints and events, `DATA-MODEL.md` for schema, `SYNC-PROTOCOL.md` for sync and conflict behaviour, `HARDWARE-INTEGRATION.md` for hardware, `ARCHITECTURE.md` §3 and §10 for device roles and remote-dashboard limits. Do not resolve a question from this page alone.

## Project Overview

G9POS is a production-quality offline-first Point of Sale (POS) system for small retail shops, beginning with a motorcycle accessories shop.

The first real deployment is my mother's shop.

The application must prioritize reliability, simplicity, and speed over fancy UI.

The owner is not tech-savvy.

The application should eventually become a commercial SaaS product.

---

# Main Goals

- Offline First
- Never lose sales
- Fast checkout
- Inventory management
- Barcode support
- Bluetooth printer support
- Remote monitoring
- Easy for non-technical users

---

# Devices

Primary

- Android Phone
- Android Tablet

Secondary

- iPhone (remote dashboard)
- Windows Laptop (remote dashboard)

---

# Hardware

Bluetooth Barcode Scanner

Bluetooth Receipt Printer

Bluetooth Label Printer — **post-launch, not in v1.** Deferred per `ARCHITECTURE.md` §4 and §12 (NIIMBOT B21).

Internet is unreliable.

Electricity may fail.

The application must continue operating offline.

---

# Tech Stack

Frontend

Flutter

State Management

Riverpod

Routing

GoRouter

Local Database

Drift (SQLite)

Backend

Go

Framework

Gin

Cloud Database

PostgreSQL

Authentication

JWT

Cloud Storage

S3 Compatible

Realtime

WebSocket

Deployment

Docker

---

# Architecture

Flutter

↓

SQLite (offline)

↓

Sync Engine

↓

Go API

↓

PostgreSQL

---

# Principles

Offline First

Simple UI

Large Buttons

Minimal typing

Fast barcode workflow

Every action logged

Automatic backup

Scalable architecture

Clean Architecture

Feature-first folder structure

---

# Core Modules

Authentication

Products

Inventory

Sales

Reports

Suppliers

Expenses

Settings

Dashboard

Remote Monitoring

---

# Future Features

Multi Shop

Warehouse

Accounting

AI Insights

Online Store

Loyalty

Analytics

---

# Performance

Open App <2 seconds

Barcode Scan <300ms

Sale Complete <2 seconds

Background Sync

Support 20,000+ products

---

# Coding Standards

Use Clean Architecture.

Use SOLID principles.

Avoid unnecessary packages.

Write production-quality code.

Always explain trade-offs.

Always prefer maintainability.

Never over-engineer.

Prefer simple solutions first.

Document every important decision.