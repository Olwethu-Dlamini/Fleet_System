# Milestones

## v1.0 MVP (Shipped: 2026-03-22)

**Phases completed:** 9 phases, 29 plans, 30 tasks

**Key accomplishments:**

- One-liner:
- One-liner:
- One-liner:
- Pino structured logging singleton wired across all service/model files with pinoHttp request tracing, plus Jest+supertest test scaffold with 11 passing tests covering FOUND-05, FOUND-06, FOUND-07
- Vehicle maintenance CRUD with date-range blocking, user contact phone fields, admin settings store, and scheduler vehicle-swap endpoint — all backed by a single migration SQL and wired into Flutter endpoint config
- One-liner:
- One-liner:
- One-liner:
- 1-minute cron auto-transitions assigned jobs to in_progress, and POST /complete endpoint enforces personnel-only authorization with GPS capture into job_completions
- Flutter assignment picker showing per-driver job counts with green glow load balancing, chip-based technician multi-select, and GPS-captured job completion flow with confirm dialog.
- One-liner:
- fl_chart hourly bar chart, badge count overlays on stat cards, Drivers/Clients toggle with grouped views, and weekend filter toggle with indicator banner
- Tenant-scoped getJobsByDate — multi-tenant data leak in getDashboardSummary todayJobs field closed with backward-compatible third parameter
- FCM push + SMTP email notification backend with deduped upcoming/overdue job cron checks, in-app notification REST API, and graceful degradation when Firebase or SMTP are not configured
- One-liner:
- One-liner:
- One-liner:
- Flutter driver/technician time extension UI: 4 models, service + provider layer, request screen with duration presets, and Add More Time button gated to in_progress assigned jobs
- One-liner:
- One-liner:
- Google Routes API v2 backend proxy + Flutter map widget with polyline, ETA, and distance on job detail screen
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- One-liner:
- Three complete user manuals for admin, scheduler, and driver/technician roles enabling customer onboarding without developer support
- docker-compose.yml

---
