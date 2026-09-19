# SteamMatch

A web application that helps Steam users find and connect with other players to form or join Family Sharing groups - making the process easier, more informed, and more organized.

## Features

- User registration and authentication (JWT + bcrypt)
- Browse and search for Steam Family Sharing groups
- Create and manage your own group
- Steam Store API integration for game library display
- Admin panel for platform management
- Role-based access control

## Tech Stack

**Backend**
- Node.js + Express
- PostgreSQL (12-table normalized schema)
- JWT Authentication
- bcrypt password encryption
- REST API

**Frontend**
- Flutter (Dart)

**Tools & Workflow**
- Git & GitHub (collaborative development)
- Postman (API testing)
- VS Code

## Project Structure

```
steamlinker/
├── steamlinker_back/     # Node.js + Express REST API
├── steamlinker_flutter/  # Flutter frontend application
└── Steamlinker BD/       # Database schema and scripts
```

## Database

The PostgreSQL schema consists of 12 normalized tables covering users, groups, memberships, games, roles, and admin management. Designed with referential integrity and scalability in mind.

## Getting Started

### Prerequisites
- Node.js v18+
- PostgreSQL 14+
- Flutter SDK

### Backend Setup
```bash
cd steamlinker_back
npm install
# Configure your .env file with DB credentials and JWT secret
npm start
```

### Frontend Setup
```bash
cd steamlinker_flutter
flutter pub get
flutter run
```

## Team

Collaborative project developed by Systems Engineering students at Universidad Tecnológica de Bolívar, Cartagena, Colombia.

## License

This project is for academic and portfolio purposes.
