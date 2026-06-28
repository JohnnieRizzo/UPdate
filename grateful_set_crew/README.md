# 🛰️ Grateful Set Crew - Field Service Management Platform

## ✨ Project Overview

Grateful Set Crew is a comprehensive Field Service Management (FSM) platform designed to streamline every stage of event staffing, from initial client lead generation to worker deployment and final billing. It manages the entire lifecycle of a service contract in one integrated system.

The platform's goal is to provide administrators with real-time oversight, automated compliance checks, and centralized tools for managing complex logistics, ensuring operational excellence at every job site.

### 🛠️ Key Modules & Features:

*   **Client Intake Funnel:** Captures initial leads from clients through a guided form, moving them through defined statuses (Intake $\rightarrow$ Research $\rightarrow$ Proposal).
*   **Contract Management:** Manages the legal agreement lifecycle, tracking status from `Draft` to `Approved`, and acting as a financial gatekeeper requiring deposit verification before activation.
*   **Worker Credentialing & HR:** A secure module for onboarding workers. It enforces mandatory credential checks (SSN, IDs, Certifications) and controls worker status transitions (`Pending` $\rightarrow$ `Oriented` $\rightarrow$ `Active`).
*   **Real-Time Job Tracking (Geo-fencing):** Processes incoming GPS location streams to monitor assigned crew members in real-time. It triggers alerts when a worker enters the **pre-shift or post-shift window**, ensuring compliance and safety.
*   **Logistics & Safety:** Automatically generates detailed, official Call Sheets for every job, including the nearest emergency hospital based on the venue's address.

## ⚙️ Installation Guide

Before running the application, ensure you have the following prerequisites installed:

*   Elixir (3.x recommended)
*   Erlang/OTP
*   Mix
*   A PostgreSQL database instance

### Step 1: Setup Dependencies
Navigate to the project root directory and fetch all necessary dependencies:

```bash
mix deps.get
```

### Step 2: Database Migration (CRITICAL!)
Run the migrations to create all required tables for Leads, Contracts, Workers, Credentials, Location Logs, etc.

```bash
# This command must be run after setting up your DATABASE_URL environment variable
mix ecto.migrate
```

### Step 3: Seed Initial Data
Seed the database with your administrator accounts and default configurations.

```bash
# This runs scripts defined in priv/repo/seeds.exs
mix run priv/repo/seeds.exs
```

## 🚀 Running Locally (Development)

For development, the application runs using Phoenix's integrated web server.

**Command:**

```bash
mix phx.server
```

**Notes:**
*   The primary administrative dashboard is accessed via `/admin`.
*   Use `DATABASE_URL` and `SECRET_KEY_BASE` environment variables to connect to your local database instance.

## 🌐 Deployment Instructions (Cloudflare/D1)

For production deployment on a cloud platform like Cloudflare, the following steps are essential:

1.  **Database Setup:** Ensure your external PostgreSQL service is configured and accessible via network credentials.
2.  **Run Migrations:** The migration step must be run as part of your CI/CD pipeline's "Pre-Deployment Hook" to guarantee schema consistency before starting the web server.
3.  **Asset Compilation:** Compile static assets (CSS, JS) using `npm run build:assets` or equivalent deployment tooling.

## ⚠️ Security & Maintenance Notes

*   **Passwords:** Never commit plaintext passwords. All initial user setup must use secure hashing functions like `Crypto.hash(:sha2, "YourSecurePassword!")`.
*   **Authorization:** The platform relies heavily on role checking (`@current_scope.user.role == "admin"`). Always double-check that access controls are in place when adding new features.
