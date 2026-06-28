# Phoenix LiveView Crew Onboarding Design

**Date:** 2026-06-10
**Status:** Design Approved
**Scope:** Linear crew member onboarding flow with skills qualification, education modules, and knowledge quiz

---

## Overview

The crew onboarding system is a hard-gated feature that prevents crew members from accessing the dispatch system until they complete a four-step sequential process:

1. **Skills/Qualifications Selection** - Crew selects job skills and certifications they're qualified for
2. **Education Modules** - Complete 5 required education modules covering GSC operations
3. **Knowledge Quiz** - Pass a 10-question quiz demonstrating understanding (8/10 passing score)
4. **Completion** - Success confirmation and redirect to dashboard

Progress persists to SQLite at each step, allowing crew members to resume from where they left off if they abandon the flow mid-way. The quiz can be retaken unlimited times until passing.

---

## Architecture & Data Model

### LiveView Structure

**Main Component:** `OnboardingLive`
- Route: `/onboarding`
- Single LiveView managing all four steps via socket assigns
- Conditionally renders sub-components based on `current_step` state
- Handles validation, persistence, and navigation

**Socket Assigns:**
```elixir
%{
  current_user: User,
  onboarding: OnboardingProgress,
  current_step: :skills | :modules | :quiz | :complete,
  selected_skills: [String],
  selected_certifications: [String],
  modules_completed: [Integer],  # module IDs
  rulebook_read: Boolean,
  quiz_progress: %{
    current_question: Integer,  # 0-9 index
    answers: [Integer],         # answer indices for each Q
    score: Integer | nil,
    attempts: Integer,
    finished: Boolean
  }
}
```

### Database Schema (Ecto)

**OnboardingProgress Schema:**
```elixir
schema "onboarding_progress" do
  belongs_to :user, User

  field :current_step, Ecto.Enum, values: [:skills, :modules, :quiz, :complete]
  field :selected_skills, {:array, :string}, default: []
  field :selected_certifications, {:array, :string}, default: []
  field :modules_completed, {:array, :integer}, default: []
  field :rulebook_read, :boolean, default: false
  field :quiz_score, :integer  # final score (0-10)
  field :quiz_attempts, :integer, default: 0
  field :completed_at, :naive_datetime  # null until completed

  timestamps()
end
```

**Skills/Certifications Data (Hardcoded in LiveView):**
```elixir
SKILLS = [
  "Stage Hand", "AV Tech", "Lighting Tech", "Rigger", "Camera Assist",
  "FOH Audio", "Monitor Engineer", "Spotlight Op", "Carpenter", "Forklift Op",
  "LED Wall Tech", "Video Director"
]

CERTIFICATIONS = [
  "OSHA 10", "OSHA 30", "Forklift Certified", "First Aid/CPR",
  "Rigging Certified", "Electrical License"
]

MODULES = [
  %{id: 1, title: "Welcome & GSC Mission", video_id: "sCpHVSrcPXc"},
  %{id: 2, title: "Safety Protocols & Stop-Work Authority", video_id: "MMGWmo9wCEo"},
  %{id: 3, title: "Full Rulebook Review", video_id: nil},
  %{id: 4, title: "Positions & Chain of Command (01-15)", video_id: nil},
  %{id: 5, title: "Uniform Standards, Strikes & Pay Rules", video_id: nil}
]

QUIZ_QUESTIONS = [10 multiple-choice questions with 4 options each]
```

---

## Component Structure

### OnboardingLive (Parent)

**Renders:**
- Progress bar header (showing current step and completion %)
- One of four step components based on `current_step`

**Handles:**
- Initial load: check if completed, load progress record, or create new
- Step transitions and validation
- Database persistence after each step
- Quiz logic and retake flow

### Sub-Components (Function Components)

#### 1. SkillsStep
**Purpose:** Collect skills and certifications selection

**UI:**
- Display 12 skill toggle buttons (tag-style)
- Display 6 certification toggle buttons
- "Continue" button (disabled until at least 1 skill selected)

**Flow:**
1. User clicks skills/certifications to toggle selection
2. User clicks "Continue"
3. Validate: at least 1 skill selected
4. Save selected_skills + selected_certifications to DB
5. Update current_step to :modules
6. Advance to ModulesStep

**Validation:**
- At least 1 skill required (show error if not selected)

#### 2. ModulesStep
**Purpose:** Complete education modules and confirm rulebook review

**UI:**
- List 5 modules with:
  - Title
  - YouTube embedded player (if video_id exists)
  - "Mark Complete" button (or checkmark if already complete)
- Checkbox: "I have read and understood the full GSC Rulebook"
- "Continue to Quiz" button (disabled until all 5 modules + rulebook checked)
- Progress indicator: "3 of 5 modules completed"

**Flow:**
1. User watches videos (optional tracking)
2. User clicks "Mark Complete" for each module
3. User checks rulebook checkbox
4. User clicks "Continue to Quiz"
5. Validate: all 5 modules marked + rulebook checked
6. Save modules_completed + rulebook_read to DB
7. Update current_step to :quiz
8. Advance to QuizStep

**Validation:**
- All 5 modules must be marked complete
- Rulebook checkbox must be checked

**Video Embed:**
```html
<iframe
  width="100%"
  height="500"
  src="https://www.youtube.com/embed/{video_id}"
  title="{module_title}"
  frameborder="0"
  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
  allowfullscreen>
</iframe>
```

#### 3. QuizStep
**Purpose:** Administer 10-question quiz and calculate score

**UI - While Taking Quiz:**
- Question counter: "Question X of 10"
- Question text
- 4 multiple-choice buttons
- After answer selected:
  - Highlight selected answer (green if correct, red if wrong)
  - Show brief feedback
  - Auto-advance after 900ms delay

**UI - After Quiz Submitted:**
- Large score display: "X/10"
- If score >= 8:
  - Success message: "You passed! You're now dispatch eligible."
  - "Go to Dashboard" button
  - Mark current_step as :complete
  - Save completed_at timestamp to DB
  - Auto-redirect to dashboard after 2 seconds
- If score < 8:
  - Message: "You need 8/10 to pass. Please review and try again."
  - "Retake Quiz" button
  - Increment quiz_attempts counter
  - Reset quiz_progress state (clear answers, current_question = 0, finished = false)
  - Return to quiz_step

**Flow:**
1. Display question 1/10
2. User clicks answer option
3. Record answer, show correct/incorrect feedback
4. Auto-advance after 900ms
5. Repeat for all 10 questions
6. After final answer, calculate score immediately
7. If score >= 8: mark complete, save to DB, advance to :complete
8. If score < 8: show score, allow retake, reset to question 1

**Validation:**
- No validation (every answer is valid)
- Ensure all 10 questions answered before scoring

#### 4. CompletionStep
**Purpose:** Confirm successful onboarding and redirect

**UI:**
- Success icon/visual
- "Welcome to the Network" heading
- "You can now receive dispatch offers" message
- "Go to Dashboard" button (or auto-redirect after 2 seconds)

---

## Data Flow & State Persistence

### Initial Load
```
1. User navigates to /onboarding
2. Mount hook:
   - Get current_user from session
   - Query OnboardingProgress for user_id
   - If completed = true → redirect to /dashboard
   - If in_progress (current_step != :complete) → load to saved step
   - If new → create blank OnboardingProgress, current_step = :skills
3. Initialize socket assigns with OnboardingProgress data
4. Render SkillsStep
```

### Step Completion Flow
```
1. User completes step (submits form or selection)
2. Client-side validation (if applicable)
3. Call changeset on OnboardingProgress struct
4. Save to SQLite
5. Update socket assigns with new state
6. Update current_step
7. Re-render (next step component displays)
```

### Quiz Submission Flow (Detailed)
```
1. User answers final question (Q10)
2. Quiz auto-advances to completion
3. Changeset: calculate score from answers
4. If score >= 8:
   a. Set current_step = :complete
   b. Set completed_at = DateTime.utc_now()
   c. Persist to DB
   d. Update socket
   e. Render CompletionStep
   f. Schedule auto-redirect to /dashboard (2s)
5. If score < 8:
   a. Show score and retake message
   b. Increment quiz_attempts
   c. Persist attempts to DB
   d. Reset quiz_progress state
   e. Stay on QuizStep, reset to question 1
```

### Session Timeout/Multi-Tab Handling
- Progress is saved to DB after each step completes
- If user abandons mid-step, last completed step is persisted
- If user returns to /onboarding in new session/tab:
  - Query DB for OnboardingProgress
  - Load to last completed step
  - No data loss
- If multiple tabs/windows: last save to DB wins (standard LiveView behavior)

---

## User Flows

### Happy Path: Complete Onboarding on First Try
```
skills_step (select skills)
  → save to DB
  → modules_step (watch videos, mark complete, check rulebook)
  → save to DB
  → quiz_step (answer all 10 Q correctly)
  → score = 10/10 (pass)
  → complete_step
  → redirect to dashboard
```

### Quiz Fail & Retake
```
quiz_step (answer questions, score = 6/10)
  → show "Need 8/10" message
  → click "Retake Quiz"
  → reset quiz state, increment attempts
  → question 1 displays again
  → answer questions again, score = 9/10 (pass)
  → complete_step
  → redirect to dashboard
```

### Abandoned Mid-Onboarding
```
User at modules_step, closes browser
  → OnboardingProgress saved to DB (skills completed, modules in progress)

User returns tomorrow, navigates to /onboarding
  → Query DB: found OnboardingProgress with current_step = :modules
  → Load to modules_step with previously selected skills
  → User can continue from modules (no re-doing skills)
```

---

## Validation & Error Handling

### Field Validation
| Step | Required Validations |
|------|----------------------|
| Skills | At least 1 skill selected |
| Modules | All 5 modules marked complete + rulebook checkbox |
| Quiz | All 10 questions answered (automatic) |

### Error Handling
- **Validation fails:** Show toast/flash message, stay on current step, allow retry
- **Database save fails:** Show "Progress not saved, please try again" message, retry button, no state change
- **Network timeout:** Disable submit button during save, show loading state, prevent double-submission
- **Unauthorized:** Redirect to /login if user session expires mid-flow

### Edge Cases
1. **Multiple tabs:** Each tab has independent socket state; DB is source of truth
2. **Quiz unlimited retakes:** No limit on quiz_attempts, can retake as many times as needed
3. **No time limits:** Crew can take days between steps (as long as logged in)
4. **Auto-logout during onboarding:** Progress saved at last completed step; resume on re-login
5. **YouTube embed fails:** Graceful fallback or note: "Watch video from external link"

---

## UI/UX Details

### Styling
- Tailwind CSS (assume available in Phoenix app)
- Follow existing GSC design system colors (navy, orange, light gray)
- Card-based layout with rounded corners and subtle shadows
- Progress bar at top showing current step visually

### Responsive Design
- Mobile: single column, full-width buttons
- Tablet/Desktop: maintain card layout, centered max-width container

### Accessibility
- Form labels associated with inputs
- Keyboard navigation support (tab through options)
- ARIA attributes for quiz answer feedback
- Color + text to convey pass/fail (not color alone)

### Icons/Visual Indicators
- Checkmarks for completed modules
- Progress bar with percentage
- Success/error toast messages
- Loading states on buttons during save

---

## Testing Strategy

### Unit Tests
- OnboardingProgress changeset validations
- Quiz score calculation logic
- Step transition logic
- Skill/certification list validation

### LiveView Tests
- Mount tests: new user, in-progress user, completed user
- Skills step: select/deselect, validate, advance
- Modules step: mark complete, rulebook checkbox, advance
- Quiz step: answer questions, calculate score, pass/fail/retake
- Completion step: redirect to dashboard

### Integration Tests
- Complete full onboarding flow (all 4 steps)
- Start onboarding, abandon, return → resume at correct step
- Failed quiz → retake → pass
- Verify DB state matches UI after each step

### Manual Testing
- Responsive design (mobile, tablet, desktop)
- YouTube embeds load and play
- Form accessibility and keyboard navigation
- Button states (enabled/disabled at correct times)

---

## Success Criteria

✅ Crew members can select skills/certifications during onboarding
✅ All 5 education modules display with YouTube embeds
✅ 10-question quiz administers correctly with instant feedback
✅ Passing score (8/10) unlocks dashboard access
✅ Failing quiz allows unlimited retakes
✅ Progress persists across sessions (resumable)
✅ Hard gate prevents access to dashboard until completed
✅ Full test coverage (unit, LiveView, integration)
✅ Responsive design on mobile, tablet, desktop
✅ No data loss on session timeout or abandonment

---

## Out of Scope

- Identity/background verification (handled elsewhere)
- Payment method setup (handled in crew profile)
- Location/availability setup (handled in crew profile)
- Video upload/management (uses external YouTube links)
- Email notifications for onboarding progress
- Onboarding reminders for abandoned users

---

## Dependencies

- Phoenix LiveView framework
- Ecto + SQLite ORM
- Tailwind CSS (styling)
- YouTube embeds (external, no library needed)
