# Crew Job Browsing Implementation Plan

## Context
Crew members need a dedicated job browsing experience separate from their active jobs dashboard. Currently, the Dashboard shows available jobs but lacks search/filtering. We'll create a new `/crew/jobs` browse page with search, filters, and detailed job view, while keeping the Dashboard focused on active/assigned work.

## Architecture Overview

### 1. New CrewLive.Jobs (Browse Page)
**Location:** `lib/grateful_set_crew_web/live/crew_live/jobs.ex`

**Purpose:** Job discovery and exploration interface

**Features:**
- List available jobs (status = "open" or "matching")
- Real-time search by job title/description
- Filter by:
  - Location (city/region matching)
  - Hourly rate range (min/max sliders)
  - Required skills (multi-select checkbox from available skills in system)
  - Job status (open/matching)
- Sort by:
  - Posted date (newest first - default)
  - Hourly rate (high to low)
  - Relevance to crew profile (skill match score)
- Job cards showing: title, location, rate, duration, match score indicator
- "View Details" button opens job detail modal

**LiveView Events:**
- `search` - Real-time text search as user types
- `toggle_filter` - Show/hide filter panel on mobile
- `update_filters` - Apply selected filters (location, rate range, skills)
- `change_sort` - Change sort order
- `view_details` - Open job detail modal

**Data Assignments:**
- `user_id`, `crew_profile`, `available_jobs`, `filtered_jobs`, `search_query`
- `filters` (map): `location`, `min_rate`, `max_rate`, `skills`, `status`
- `sort_by`, `show_filters`

### 2. CrewLive.JobDetail (Modal)
**Location:** `lib/grateful_set_crew_web/live/crew_live/job_detail.ex`

**Purpose:** Detailed job view with application workflow

**Features:**
- Full job details: title, description, location, rate, hours, required skills
- Client info: name, rating (if available)
- Match score calculation (using Dispatch engine scoring)
- "Apply Now" button (expresses interest)
- "Already matched with this job" message if crew_id matches
- Application status tracking (applied, accepted, rejected, pending)

**LiveView Events:**
- `apply_for_job` - Create JobApplication record
- `close_detail` - Close modal

**Data Assignments:**
- `job`, `crew_profile`, `current_user_id`, `match_score`, `application_status`

### 3. Update Jobs Context
**Location:** `lib/grateful_set_crew/jobs.ex`

**New Functions:**
```elixir
def list_available_jobs_for_crew(crew_id, filters \\ %{})
  # Returns available jobs filtered by crew preferences
  # Applies search, location, rate, skills filters
  # Returns with calculated match_score from Dispatch

def calculate_crew_job_match(job, crew)
  # Returns match score (0-100) using Dispatch scoring
  # Uses: location (40), skills (40), rating (10), availability (10)

def apply_for_job(job_id, crew_id, opts \\ [])
  # Creates JobApplication or JobInterest record
  # Returns changeset or {:ok, application}

def get_all_skills()
  # Returns all unique skills from crew profiles
```

**Existing Functions Used:**
- `list_available_jobs()` - Base query for available jobs
- Dispatch.run(job_id) - Already handles auto-assignment if score >= 70

### 4. Create JobApplication Schema
**Location:** `lib/grateful_set_crew/jobs/application.ex`

**Schema:**
```elixir
schema "job_applications" do
  belongs_to :job, Job, type: :binary_id
  belongs_to :crew, User, type: :id

  field :status, :string, default: "applied"  # applied, accepted, rejected, expired
  field :applied_at, :utc_datetime
  field :responded_at, :utc_datetime
  field :match_score, :float

  timestamps(type: :utc_datetime)
end
```

**Changeset Validations:**
- `validate_required([:job_id, :crew_id, :status])`
- `validate_inclusion(:status, ["applied", "accepted", "rejected", "expired"])`
- Unique constraint on (job_id, crew_id) - one application per crew per job

### 5. Update Routes
**Location:** `lib/grateful_set_crew_web/router.ex`

**New Routes (in crew scope):**
```elixir
live "/jobs", CrewLive.Jobs, :index           # Browse/search jobs
```

### 6. Update Dashboard
**Location:** `lib/grateful_set_crew_web/live/crew_live/dashboard.ex`

**Changes:**
- Remove job browse from dashboard (move to /crew/jobs)
- Keep only: active/assigned jobs, pending jobs, notifications
- Add nav link to "/crew/jobs" for browsing
- Update metrics to show status instead of available jobs count

### 7. Database Migration
**New Migration:** `priv/repo/migrations/20260520205000_create_job_applications.exs`

Creates `job_applications` table with:
- job_id (FK, binary_id)
- crew_id (FK, integer)
- status (string)
- applied_at, responded_at (timestamps)
- match_score (float)
- Unique index on (job_id, crew_id)
- Indexes on crew_id, status, applied_at

## Implementation Status

### Completed ✅
1. **Create JobApplication schema and migration**
   - ✅ Schema created at `lib/grateful_set_crew/jobs/application.ex`
   - ✅ Migration created and executed successfully
   - ✅ Table structure with proper indexes and unique constraints

2. **Add Jobs context functions**
   - ✅ `list_available_jobs_for_crew/2` with comprehensive filtering
   - ✅ `calculate_crew_job_match/2` using Dispatch scoring algorithm
   - ✅ `apply_for_job/3` to create JobApplication records
   - ✅ `get_job_application/2` to check existing applications
   - ✅ `list_job_applications/1` to list applications for a job
   - ✅ `list_crew_applications/1` to list applications for a crew member
   - ✅ `get_all_skills/0` to retrieve all unique skills from system

3. **Create CrewLive.Jobs browse page**
   - ✅ Job listing with cards and match scores
   - ✅ Real-time search input (debounced)
   - ✅ Filter UI with:
     - Search by title/description
     - Location filtering
     - Hourly rate range (min/max)
     - Skills multi-select
   - ✅ Sort options:
     - Posted date (newest first - default)
     - Hourly rate (high to low, low to high)
     - Match score (relevance)
   - ✅ Mobile-responsive filter panel (toggle on mobile, visible on desktop)
   - ✅ Job detail modal component

4. **Update routes**
   - ✅ Added `/crew/jobs` route to crew scope
   - ✅ Properly authenticated with `:require_crew_onboarded` pipeline

5. **Update Dashboard**
   - ✅ Removed job browsing section
   - ✅ Updated metrics to show status instead of available jobs count
   - ✅ Added CTA to browse jobs at `/crew/jobs`
   - ✅ Cleaned up event handlers

### Remaining ⏳
7. **Create tests for job browsing feature**
   - Job listing tests with various filters
   - Search functionality tests
   - Application creation tests
   - Match score calculation tests

## File Summary

### New Files Created
- `lib/grateful_set_crew/jobs/application.ex` - JobApplication schema
- `lib/grateful_set_crew_web/live/crew_live/jobs.ex` - Browse/search page
- `priv/repo/migrations/20260520205000_create_job_applications.exs` - Database migration

### Modified Files
- `lib/grateful_set_crew/jobs.ex` - Added 6 new context functions
- `lib/grateful_set_crew_web/router.ex` - Added `/crew/jobs` route
- `lib/grateful_set_crew_web/live/crew_live/dashboard.ex` - Removed job browsing, updated metrics

## Key Features Implemented

### Search & Filtering
- Text search across job title and description (debounced for real-time feel)
- Location filtering with city/region matching
- Hourly rate range filtering (min/max)
- Skills-based filtering (shows jobs matching crew's skills)
- Status filtering (open/matching)
- Multiple sort options

### Job Matching
- Intelligent match score calculation (0-100%)
- Uses same algorithm as Dispatch engine:
  - Location: 40 points
  - Skills: 40 points
  - Rating: 10 points
  - Availability: 10 points
- Displayed prominently on job cards and detail modal

### Application Management
- One-click "Apply Now" button
- Prevents duplicate applications (unique constraint)
- Tracks application status (applied, accepted, rejected, expired)
- Shows application status on job cards when already applied

### Real-time Updates
- PubSub subscription to job creation/updates
- Jobs list refreshes when new jobs are posted
- Modal closes automatically after successful application

### Mobile Responsiveness
- Collapsible filter panel on mobile devices
- Full filter functionality on desktop
- Responsive grid layout

## Testing Strategy (To Be Implemented)

**Unit Tests:**
- Jobs context functions (filtering, matching)
- JobApplication changeset validations

**LiveView Tests:**
- Job listing with various filters
- Search functionality
- Job detail modal
- Apply for job workflow
- Empty state and error handling

## Verification Checklist

- [x] Compilation: `mix compile` passes without errors
- [x] Database: Migration runs successfully
- [ ] Manual Testing:
  - [ ] Navigate to `/crew/jobs` as authenticated crew
  - [ ] Search for jobs by text
  - [ ] Filter by location, rate, skills
  - [ ] Click job card to view details
  - [ ] Click "Apply Now" and verify application created
  - [ ] Check match score display
- [ ] Test Suite: All new tests pass, existing tests unaffected
- [ ] End-to-End: Client posts job → Crew browses and applies → See application in system

## Dependencies & Assumptions

- ✅ Dispatch engine already exists and works correctly
- ✅ PubSub infrastructure in place for real-time updates
- ✅ User authentication/authorization working
- ✅ Jobs context and schema fully functional
- ✅ Crew profiles populated with skills data

## Notes

- Match score calculation reuses Dispatch.run/1 logic (40/40/10/10)
- Job applications are separate from auto-matching (can coexist)
- Skills filtering uses crew profile skills array intersection
- Location matching: exact city match first, then fallback to distance-based
- All filtering is done in the Elixir context for type safety and flexibility
- Modal detail view is embedded in the Jobs LiveView template for simplicity
