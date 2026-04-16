# Time Extension Approval Workflow - UX Research

**Date:** 2026-03-25
**Context:** Vehicle scheduling app where technicians request extra time; scheduler approves/denies with cascading schedule impact.

---

## 1. Approval Actions - What Your System Should Offer

### Current Implementation (already built)
Your system already has three suggestion types: `push`, `swap`, `custom`. This is a solid foundation.

### Recommended Full Action Set

| Action | Type Tag | When to Show | What It Does |
|--------|----------|--------------|--------------|
| **Approve (push jobs)** | `push` | Always, if later jobs exist | Shifts all subsequent jobs forward by N minutes |
| **Approve (reassign next job)** | `swap` | When another driver/tech is free | Moves the conflicting job to an available person |
| **Approve (cancel next job)** | `cancel` | When the conflicting job is low-priority or near end-of-day | Cancels the next job, notifies customer for reschedule |
| **Approve (split the day)** | `split` | When 2+ jobs are affected and a second crew is available | Hands remaining jobs to another crew member |
| **Approve (no impact)** | `none` | When no later jobs exist or buffer time absorbs it | Just extends the job, nothing else changes |
| **Deny** | `deny` | Always | Rejects with mandatory reason |
| **Custom times** | `custom` | Always | Scheduler manually enters new times |

### What Real Systems Add Beyond Your Current Set

1. **"Cancel and reschedule" (not just cancel)** - ServiceTitan and Housecall Pro distinguish between unscheduling (remove from today, put back in queue) and cancelling (done, notify customer). Your system should offer "Unschedule conflicting job" which moves it to unassigned queue rather than outright cancelling.

2. **"Partial approval"** - Approve fewer minutes than requested. Technician asks for 60 min, scheduler grants 30. This is common in ServiceMax workflows where SLA constraints limit flexibility.

3. **"Approve with overtime flag"** - Accept the extension but flag the driver as going into overtime. Important for labor cost tracking.

---

## 2. How Leading FSM Systems Handle Schedule Overruns

### ServiceTitan
- Uses a **dispatch board** (drag-and-drop calendar) as the primary interface
- When a job runs long, dispatchers see it visually overflow into the next time slot
- **Does NOT auto-suggest fixes** - relies on dispatcher judgment with visual cues
- Offers "Scheduling Pro" with capacity planning that shows overbooking indicators

### Housecall Pro
- Distinguishes **Unschedule vs Cancel vs Delete** as three distinct actions
- Unschedule = remove from calendar but keep the job (re-queue it)
- Cancel = job is done, customer notified
- No auto-recommendation engine; manual dispatcher workflow

### Jobber
- Real-time schedule view with conflict highlighting
- **Drag-and-drop reassignment** is the primary resolution method
- Notifications alert dispatchers but resolution is manual

### ServiceMax (PTC)
- **Service Board** provides one-click scheduling recommendations
- Uses skill matching, travel time, and SLA data to suggest optimal reassignment
- Most sophisticated: considers technician certifications, parts availability, customer priority tiers

### Salesforce Field Service
- Einstein Copilot highlights "appointments with rule violations, overlaps, SLA risks"
- Converts each violation category into a **filter** so dispatchers can triage
- Autonomous Scheduling Agent can auto-resolve conflicts without human intervention (enterprise tier)

### Pattern Summary
Most systems show the problem visually and let dispatchers resolve manually. **Your auto-suggestion approach is actually ahead of the curve for an SMB product.** The key differentiator would be making suggestions smart enough that schedulers trust them.

---

## 3. Notification-to-Action Flow Best Practices

### The Golden Rule
**Tapping a notification should land the user on the decision screen with all context pre-loaded, ready to act in one tap.**

### Recommended Flow

```
Push Notification arrives:
  "Job #1042: 30 min extension requested by John"
    |
    v
Tap notification
    |
    v
Deep-link to TimeExtensionApprovalScreen(jobId: X, requestId: Y)
    |
    v
Screen loads with:
  - Request details (already implemented)
  - Impact analysis (already implemented)
  - Day schedule view (already implemented)
  - Pre-selected recommendation based on impact severity
    |
    v
One tap: Approve recommended option
  OR
Two taps: Select different option + Approve
```

### Key UX Decisions

| Question | Recommendation | Reason |
|----------|---------------|--------|
| Open job detail first, or approval screen? | **Approval screen directly** | Scheduler needs to act, not browse. Job context is embedded in the approval screen already. |
| Pre-select a suggestion? | **Yes, pre-select the "recommended" option** | Reduces cognitive load. Highlight it with a "Recommended" badge. |
| Show notification badge count? | **Yes, on dashboard and in bottom nav** | Schedulers need to see pending requests at a glance |
| Allow bulk approval? | **Not yet** - single approval is fine for v1 | Bulk adds complexity; most fleets have <5 extensions/day |

### Deep Link Implementation (Flutter)
Your FCM service should include `jobId` and `requestId` in the notification payload. On tap, navigate directly:
```dart
Navigator.pushNamed(context, '/time-extension/approve',
  arguments: {'jobId': jobId, 'requestId': requestId});
```

---

## 4. Smart Recommendations Engine

### Impact Severity Categories

| Severity | Condition | Auto-Recommendation | Confidence |
|----------|-----------|---------------------|------------|
| **None** | No jobs scheduled after, or buffer absorbs extension | "Approve" (no changes needed) | Show as green, pre-select |
| **Minor** | 1-2 jobs pushed by <=30 min, all still within business hours | "Push all jobs by N min" | Show as blue, pre-select |
| **Moderate** | Jobs pushed past business hours, OR 3+ jobs affected | "Reassign" if driver available, else "Push" with warning | Show as orange |
| **Major** | Last job would end past 18:00, OR customer SLA at risk | "Cancel/unschedule last job" + "Reassign" options | Show as red, require explicit choice |

### Data That Drives Each Recommendation

```
For each time extension request, compute:

1. GAP ANALYSIS
   - Time between current job's new end and next job's start
   - If gap >= extension_minutes: severity = NONE

2. CASCADE ANALYSIS
   - For each affected job: new_end_time after push
   - last_job_new_end vs business_hours_end (e.g., 17:00)
   - If last_job overflows: severity >= MODERATE

3. AVAILABILITY CHECK (already implemented as swap suggestion)
   - Query free drivers/techs during conflict window
   - If available: offer reassignment as primary recommendation

4. PRIORITY CHECK (enhancement)
   - Compare priority of requesting job vs affected jobs
   - High-priority job requesting extension + low-priority affected job
     = recommend cancel/unschedule the low-priority one
```

### Recommendation Display Order

Show suggestions in this order (most recommended first):
1. The auto-recommended option (highlighted, pre-selected)
2. Other viable options
3. Custom times (always last)

### Backend Enhancement Needed

Your `_buildSuggestions` currently always generates push + swap + custom. Enhance to:

1. **Add severity level** to the response: `{ severity: 'none' | 'minor' | 'moderate' | 'major' }`
2. **Add a `recommended` flag** on the best suggestion: `{ ...suggestion, recommended: true }`
3. **Add `cancel`/`unschedule` suggestion type** when the last affected job would overflow business hours
4. **Add `none` suggestion type** when no jobs are actually impacted (just approve, no reschedule needed)

---

## 5. Quick Wins for Your Implementation

### Already Strong
- Impact analysis with affected jobs list
- Day schedule view showing full context
- Push/swap/custom suggestion types
- Deny with reason dialog

### Add These Next (priority order)

1. **Severity badge on the approval screen** - Color-coded (green/blue/orange/red) based on impact analysis. Helps scheduler instantly gauge urgency.

2. **Pre-select recommended option** - When severity is none/minor, auto-select the best suggestion so scheduler can approve with one tap.

3. **"No impact" fast path** - If `affectedJobs.length == 0`, show a simplified screen: just the request info and a big "Approve" button. No need to show empty suggestion cards.

4. **Unschedule option** - Add a `cancel` suggestion type that removes the last conflicting job from the schedule (puts it back in unassigned queue) rather than pushing everything.

5. **Partial approval** - Allow scheduler to approve fewer minutes than requested (e.g., "Grant 30 of 60 minutes requested").

---

## Sources

- [ServiceTitan Scheduling Pro](https://www.servicetitan.com/features/pro/scheduling)
- [ServiceMax Service Board](https://www.ptc.com/en/products/servicemax/service-board)
- [Housecall Pro: Unschedule vs Cancel vs Delete](https://help.housecallpro.com/en/articles/2865052-unschedule-vs-cancel-vs-delete)
- [Salesforce Field Service Scheduling](https://help.salesforce.com/s/articleView?id=service.pfs_scheduling_services.htm&language=en_US&type=5)
- [Salesforce FSL Deep Linking](https://developer.salesforce.com/docs/atlas.en-us.field_service_dev.meta/field_service_dev/fsl_dev_mobile_deep_linking.htm)
- [Fieldcode: Overcoming Scheduling Conflicts](https://fieldcode.com/en/field-service-daily/overcoming-scheduling-conflicts-in-field-service-simple-solutions-to-streamline-your-operations)
- [BuildOps: Field Service Scheduling Guide](https://buildops.com/resources/field-service-scheduling/)
