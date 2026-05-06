# AD-Tools-CNAS

> A web-based Active Directory administration tool built with PowerShell Universal, developed during an internship at **CNAS ** (Caisse Nationale des Assurances Sociales).

---

## Overview

**AD-Tools-CNAS** is an internal web application designed to simplify and automate the daily administration of Active Directory within the CNAS domain . It provides a clean, user-friendly interface for IT administrators to manage users, groups, computers, and generate reports — without needing to use native AD tools directly.

This project was developed as part of the implementation of Active Directory at the CNAS  agency, aiming to centralize IT resource management and strengthen information system security.

---

## Features

### 👤 User Management
- Search users by name, department, or payment center
- Create new domain user accounts
- Reset passwords and unlock accounts
- Restore deleted users from the AD Recycle Bin

### 👥 Group Management
- Search and list all CNAS security groups
- Create new groups with custom scope and type
- Manage group membership (add/remove users)

### 🖥️ Infrastructure
- Search domain-joined computers and view their details
- Monitor inactive machines
- View domain controllers information

### 🔍 Object Search
- Search any AD object (user, group, computer) using PowerShell filter syntax or LDAP filter
- View object attributes and distinguished names

### 📊 Reports
- Users Inactive (30+ days)
- Users Locked Out
- Users Recently Created / Modified
- Users Never Logged On
- Users Expiring Passwords
- Users Group Membership
- Computers Recently Added / Inactive / Disabled
- Groups Empty / Recently Modified / Members Report
- Accounts Soon to Expire
- OU Structure Overview
- Security Privileged Accounts
- Security Group Policy Links

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Backend | PowerShell scripts (Active Directory module) |
| Frontend | PowerShell Universal (PSU) web dashboard |
| Auth | Kerberos / Windows Authentication (SSO) |
| Hosting | Windows Server (domain member) |
| Directory | Active Directory Domain Services (AD DS) |

---

## Architecture

```
┌─────────────────────────────────────────┐
│          PSU Web Dashboard              │
│     (Internal URL, domain access)       │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│         PowerShell Backend              │
│   AD module queries & write operations  │
└────────────────┬────────────────────────┘
                 │
┌────────────────▼────────────────────────┐
│     Active Directory (ag26.cnas.dz)     │
│   Domain Controller — Windows Server    │
└─────────────────────────────────────────┘
```

---

## Access & Security

Access is restricted exclusively to authorized IT administrators of the CNAS domain:

- **Super Admins** — `GRP-Users-Informatique` group: full access to all features.
- **Local Admins** — delegated sub-groups (e.g. `GRP-Admins-CentreMedeaVille`): limited to their own OU.
- All other domain users have **no access** to the application.

Authentication is handled via **Kerberos SSO** — administrators logged into their Windows session are recognized automatically without re-entering credentials.

Every administrative action is logged with the AD account of the administrator who performed it, ensuring full auditability.

---




## Context

This application was developed as part of an internship report for the **2nd year Superior Cycle (2CS)**, option **Systèmes Informatiques (SIQ)** at the **École Nationale Supérieure d'Informatique (ESI)**, under the supervision of **M. Rabhi Djamel**, IT engineer at CNAS .

---

## Author

**Djoghlal Romaisa**  
ESI — École Nationale Supérieure d'Informatique  
Academic Year: 2025/2026
