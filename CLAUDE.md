# Vehicle Scheduling System

## Project Overview
A vehicle/fleet scheduling system with a Node.js/Express backend and a Flutter mobile app frontend. Uses MySQL for data storage.

## Architecture
- **Backend**: `vehicle-scheduling-backend/` — Node.js + Express REST API
  - Entry point: `src/server.js`
  - Routes in `src/routes/`, models in `src/models/`
  - Auth: JWT-based (`bcrypt`/`bcryptjs`, `jsonwebtoken`)
  - Database: MySQL (`mysql2`)
  - API docs: Swagger (`swagger-jsdoc`, `swagger-ui-express`)
- **Frontend**: `vehicle_scheduling_app/` — Flutter (Dart)
  - State management: Provider pattern (`lib/providers/`)
  - Screens: `lib/screens/`, Services: `lib/services/`, Models: `lib/models/`
  - Config: `lib/config/app_config.dart`
- **Database**: SQL schemas in `vehicle_scheduling.sql` and `vehicle_scheduling2.sql`

## Common Commands
```bash
# Backend
cd vehicle-scheduling-backend && npm install
npm run dev          # Start with nodemon (development)
npm start            # Start production

# Flutter app
cd vehicle_scheduling_app && flutter pub get
flutter run          # Run on connected device/emulator
```

## Key Conventions
- Backend uses Express 5.x
- Environment config via `.env` (see `.env.example`)
- Git commit messages should be descriptive of changes made
- No tests are currently configured (`npm test` is a placeholder)

## CRITICAL: No Secrets in Git
- **NEVER commit API keys, secrets, tokens, or credentials to git**
- Before EVERY `git add`/`commit`/`push`, scan staged files for secrets:
  ```bash
  grep -rn "AIza\|sk-\|AKIA\|password.*=.*['\"][^'\"]\|secret.*=.*['\"][^'\"]\|api.key.*=.*['\"][^'\"]" --include="*.dart" --include="*.js" --include="*.json" --include="*.xml" --include="*.html" --include="*.swift" --include="*.yaml" --include="*.md" <files being staged>
  ```
- API keys belong in `.env` (gitignored), NEVER in source files
- Flutter platform files (AndroidManifest.xml, AppDelegate.swift, web/index.html) must use `YOUR_*` placeholders — real keys injected at build time
- Check `.planning/` docs too — research files often quote real keys
- If a key is found, replace with placeholder BEFORE committing. No exceptions.

## Important Notes
- `.env` files contain secrets — never commit them
- The app supports admin features like driver hotswapping for jobs
- Database includes test data for presentations
