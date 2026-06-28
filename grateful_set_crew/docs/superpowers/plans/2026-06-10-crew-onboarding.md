# Crew Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder orientation flow with a full four-step crew onboarding LiveView covering skills selection, education modules, a 10-question quiz, and a completion screen — with progress persisted to SQLite after every step.

**Architecture:** Single `OnboardingLive` at `/onboarding` replaces `OrientationLive.Index` at `/orientation`. The existing `orientation_progress` table is altered in-place (new columns added, old ones removed). The `Orientation` context gets dedicated functions for each step transition. All four steps are function components rendered inside a single LiveView based on `current_step`.

**Tech Stack:** Phoenix LiveView 1.1, Ecto + SQLite3 (ecto_sqlite3), Tailwind CSS, ExUnit + Phoenix.LiveViewTest

---

## File Map

| Action | Path | Purpose |
|--------|------|---------|
| Create | `priv/repo/migrations/20260610000001_update_orientation_progress_for_onboarding.exs` | Alter table: remove old columns, add new onboarding columns |
| Modify | `lib/grateful_set_crew/orientation/progress.ex` | Updated schema matching new columns |
| Modify | `lib/grateful_set_crew/orientation.ex` | New context functions: save_skills, save_modules, complete_onboarding, increment_quiz_attempts |
| Modify | `lib/grateful_set_crew_web/user_auth.ex` | Update `require_orientation_complete` redirect from `/orientation` to `/onboarding` |
| Modify | `lib/grateful_set_crew_web/router.ex` | Replace `/orientation` route with `/onboarding` route using `OnboardingLive` |
| Create | `lib/grateful_set_crew_web/live/onboarding_live.ex` | Full onboarding LiveView with all four step components |
| Delete | `lib/grateful_set_crew_web/live/orientation_live/index.ex` | Remove obsolete placeholder |
| Create | `test/grateful_set_crew/orientation_test.exs` | Unit tests for Progress changeset + Orientation context |
| Create | `test/grateful_set_crew_web/live/onboarding_live_test.exs` | LiveView integration tests for all four steps |

---

## Task 1: Database Migration + Schema

**Files:**
- Create: `priv/repo/migrations/20260610000001_update_orientation_progress_for_onboarding.exs`
- Modify: `lib/grateful_set_crew/orientation/progress.ex`

- [ ] **Step 1: Write failing schema unit tests**

Create `test/grateful_set_crew/orientation_test.exs`:

```elixir
defmodule GratefulSetCrew.OrientationTest do
  use GratefulSetCrew.DataCase

  alias GratefulSetCrew.Orientation
  alias GratefulSetCrew.Orientation.Progress
  alias GratefulSetCrew.AccountsFixtures

  describe "Progress changeset" do
    setup do
      user = AccountsFixtures.user_fixture(%{role: "crew"})
      {:ok, user: user}
    end

    test "valid changeset with required fields", %{user: user} do
      changeset = Progress.changeset(%Progress{}, %{user_id: user.id})
      assert changeset.valid?
    end

    test "requires user_id" do
      changeset = Progress.changeset(%Progress{}, %{})
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects invalid current_step" do
      changeset = Progress.changeset(%Progress{}, %{user_id: 1, current_step: "intro"})
      assert %{current_step: _} = errors_on(changeset)
    end

    test "accepts valid current_step values" do
      for step <- ["skills", "modules", "quiz", "complete"] do
        changeset = Progress.changeset(%Progress{}, %{user_id: 1, current_step: step})
        refute Map.has_key?(errors_on(changeset), :current_step),
          "Expected #{step} to be valid"
      end
    end

    test "stores selected_skills as string array", %{user: user} do
      {:ok, progress} =
        %Progress{}
        |> Progress.changeset(%{
          user_id: user.id,
          selected_skills: ["Stage Hand", "AV Tech"],
          selected_certifications: ["OSHA 10"]
        })
        |> GratefulSetCrew.Repo.insert()

      assert progress.selected_skills == ["Stage Hand", "AV Tech"]
      assert progress.selected_certifications == ["OSHA 10"]
    end

    test "stores modules_completed as integer array", %{user: user} do
      {:ok, progress} =
        %Progress{}
        |> Progress.changeset(%{
          user_id: user.id,
          modules_completed: [1, 2, 3]
        })
        |> GratefulSetCrew.Repo.insert()

      assert progress.modules_completed == [1, 2, 3]
    end

    test "stores quiz_score and quiz_attempts", %{user: user} do
      {:ok, progress} =
        %Progress{}
        |> Progress.changeset(%{
          user_id: user.id,
          quiz_score: 9,
          quiz_attempts: 2
        })
        |> GratefulSetCrew.Repo.insert()

      assert progress.quiz_score == 9
      assert progress.quiz_attempts == 2
    end

    test "defaults rulebook_read to false", %{user: user} do
      {:ok, progress} =
        %Progress{}
        |> Progress.changeset(%{user_id: user.id})
        |> GratefulSetCrew.Repo.insert()

      assert progress.rulebook_read == false
    end
  end
end
```

- [ ] **Step 2: Run to verify tests fail**

```bash
cd grateful_set_crew && mix test test/grateful_set_crew/orientation_test.exs
```

Expected: compilation error or test failures — `selected_skills`, `modules_completed` (integer), `rulebook_read`, `quiz_score`, `quiz_attempts` fields don't exist yet.

- [ ] **Step 3: Create the migration**

Create `priv/repo/migrations/20260610000001_update_orientation_progress_for_onboarding.exs`:

```elixir
defmodule GratefulSetCrew.Repo.Migrations.UpdateOrientationProgressForOnboarding do
  use Ecto.Migration

  def up do
    alter table(:orientation_progress) do
      remove :modules_completed
      remove :quiz_passed
    end

    alter table(:orientation_progress) do
      add :selected_skills, {:array, :string}, default: []
      add :selected_certifications, {:array, :string}, default: []
      add :modules_completed, {:array, :integer}, default: []
      add :rulebook_read, :boolean, default: false
      add :quiz_score, :integer
      add :quiz_attempts, :integer, default: 0
    end

    execute "UPDATE orientation_progress SET current_step = 'skills' WHERE current_step = 'intro'"
  end

  def down do
    alter table(:orientation_progress) do
      remove :selected_skills
      remove :selected_certifications
      remove :modules_completed
      remove :rulebook_read
      remove :quiz_score
      remove :quiz_attempts
    end

    alter table(:orientation_progress) do
      add :modules_completed, {:array, :string}, default: []
      add :quiz_passed, :boolean, default: false
    end

    execute "UPDATE orientation_progress SET current_step = 'intro' WHERE current_step = 'skills'"
  end
end
```

- [ ] **Step 4: Update the Progress schema**

Replace the full content of `lib/grateful_set_crew/orientation/progress.ex`:

```elixir
defmodule GratefulSetCrew.Orientation.Progress do
  use Ecto.Schema
  import Ecto.Changeset

  schema "orientation_progress" do
    belongs_to :user, GratefulSetCrew.Accounts.User

    field :current_step, :string, default: "skills"
    field :selected_skills, {:array, :string}, default: []
    field :selected_certifications, {:array, :string}, default: []
    field :modules_completed, {:array, :integer}, default: []
    field :rulebook_read, :boolean, default: false
    field :quiz_score, :integer
    field :quiz_attempts, :integer, default: 0
    field :completed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(progress, attrs) do
    progress
    |> cast(attrs, [
      :user_id, :current_step, :selected_skills, :selected_certifications,
      :modules_completed, :rulebook_read, :quiz_score, :quiz_attempts, :completed_at
    ])
    |> validate_required([:user_id])
    |> validate_inclusion(:current_step, ["skills", "modules", "quiz", "complete"])
    |> unique_constraint(:user_id)
  end
end
```

- [ ] **Step 5: Run migration and tests**

```bash
cd grateful_set_crew && mix ecto.migrate && mix test test/grateful_set_crew/orientation_test.exs
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add priv/repo/migrations/20260610000001_update_orientation_progress_for_onboarding.exs \
        lib/grateful_set_crew/orientation/progress.ex \
        test/grateful_set_crew/orientation_test.exs
git commit -m "feat: update orientation_progress schema for onboarding flow"
```

---

## Task 2: Orientation Context Functions

**Files:**
- Modify: `lib/grateful_set_crew/orientation.ex`
- Modify: `test/grateful_set_crew/orientation_test.exs` (add context tests)

- [ ] **Step 1: Add failing context tests**

Append the following `describe` blocks to `test/grateful_set_crew/orientation_test.exs` (inside the module, after the existing describe block):

```elixir
  describe "create_progress/1" do
    test "creates progress record with default skills step" do
      user = AccountsFixtures.user_fixture(%{role: "crew"})
      assert {:ok, progress} = Orientation.create_progress(user.id)
      assert progress.current_step == "skills"
      assert progress.selected_skills == []
      assert progress.modules_completed == []
    end
  end

  describe "save_skills/2" do
    test "saves skills and advances to modules step" do
      user = AccountsFixtures.user_fixture(%{role: "crew"})
      {:ok, progress} = Orientation.create_progress(user.id)

      assert {:ok, updated} = Orientation.save_skills(progress, %{
        selected_skills: ["Stage Hand", "AV Tech"],
        selected_certifications: ["OSHA 10"],
        current_step: "modules"
      })

      assert updated.current_step == "modules"
      assert updated.selected_skills == ["Stage Hand", "AV Tech"]
      assert updated.selected_certifications == ["OSHA 10"]
    end
  end

  describe "save_modules/2" do
    test "saves module completion and advances to quiz step" do
      user = AccountsFixtures.user_fixture(%{role: "crew"})
      {:ok, progress} = Orientation.create_progress(user.id)

      assert {:ok, updated} = Orientation.save_modules(progress, %{
        modules_completed: [1, 2, 3, 4, 5],
        rulebook_read: true,
        current_step: "quiz"
      })

      assert updated.current_step == "quiz"
      assert updated.modules_completed == [1, 2, 3, 4, 5]
      assert updated.rulebook_read == true
    end
  end

  describe "complete_onboarding/2" do
    test "marks progress complete with score and timestamp" do
      user = AccountsFixtures.user_fixture(%{role: "crew"})
      {:ok, progress} = Orientation.create_progress(user.id)

      assert {:ok, updated} = Orientation.complete_onboarding(progress, 9)

      assert updated.current_step == "complete"
      assert updated.quiz_score == 9
      assert updated.completed_at != nil
    end
  end

  describe "increment_quiz_attempts/2" do
    test "increments attempts and records last score" do
      user = AccountsFixtures.user_fixture(%{role: "crew"})
      {:ok, progress} = Orientation.create_progress(user.id)

      assert {:ok, updated} = Orientation.increment_quiz_attempts(progress, 6)

      assert updated.quiz_attempts == 1
      assert updated.quiz_score == 6
    end

    test "accumulates across multiple failures" do
      user = AccountsFixtures.user_fixture(%{role: "crew"})
      {:ok, progress} = Orientation.create_progress(user.id)
      {:ok, progress} = Orientation.increment_quiz_attempts(progress, 5)
      assert {:ok, updated} = Orientation.increment_quiz_attempts(progress, 7)
      assert updated.quiz_attempts == 2
    end
  end

  describe "is_complete?/1" do
    test "returns false for non-complete steps" do
      for step <- ["skills", "modules", "quiz"] do
        progress = %GratefulSetCrew.Orientation.Progress{current_step: step}
        refute Orientation.is_complete?(progress)
      end
    end

    test "returns true when current_step is complete" do
      progress = %GratefulSetCrew.Orientation.Progress{current_step: "complete"}
      assert Orientation.is_complete?(progress)
    end
  end
```

- [ ] **Step 2: Run to verify tests fail**

```bash
cd grateful_set_crew && mix test test/grateful_set_crew/orientation_test.exs
```

Expected: failures on `save_skills/2`, `save_modules/2`, `complete_onboarding/2`, `increment_quiz_attempts/2`.

- [ ] **Step 3: Update the Orientation context**

Replace the full content of `lib/grateful_set_crew/orientation.ex`:

```elixir
defmodule GratefulSetCrew.Orientation do
  import Ecto.Query, warn: false
  alias GratefulSetCrew.Repo
  alias GratefulSetCrew.Orientation.Progress

  def get_progress!(user_id), do: Repo.get_by!(Progress, user_id: user_id)
  def get_progress(user_id), do: Repo.get_by(Progress, user_id: user_id)

  def create_progress(user_id) do
    %Progress{}
    |> Progress.changeset(%{user_id: user_id})
    |> Repo.insert()
  end

  def update_progress(%Progress{} = progress, attrs) do
    progress
    |> Progress.changeset(attrs)
    |> Repo.update()
  end

  def save_skills(%Progress{} = progress, attrs) do
    update_progress(progress, attrs)
  end

  def save_modules(%Progress{} = progress, attrs) do
    update_progress(progress, attrs)
  end

  def complete_onboarding(%Progress{} = progress, score) do
    update_progress(progress, %{
      quiz_score: score,
      current_step: "complete",
      completed_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  def increment_quiz_attempts(%Progress{} = progress, score) do
    update_progress(progress, %{
      quiz_score: score,
      quiz_attempts: (progress.quiz_attempts || 0) + 1
    })
  end

  def is_complete?(%Progress{} = progress), do: progress.current_step == "complete"
end
```

- [ ] **Step 4: Run tests**

```bash
cd grateful_set_crew && mix test test/grateful_set_crew/orientation_test.exs
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/grateful_set_crew/orientation.ex \
        test/grateful_set_crew/orientation_test.exs
git commit -m "feat: add onboarding-specific context functions to Orientation"
```

---

## Task 3: Router + Auth Updates

**Files:**
- Modify: `lib/grateful_set_crew_web/user_auth.ex` (line 283)
- Modify: `lib/grateful_set_crew_web/router.ex` (lines 99-103)

- [ ] **Step 1: Update the orientation redirect in user_auth.ex**

In `lib/grateful_set_crew_web/user_auth.ex`, find `require_orientation_complete` (around line 275) and change the redirect from `/orientation` to `/onboarding`:

Old:
```elixir
      conn
      |> put_flash(:error, "Please complete orientation first.")
      |> redirect(to: ~p"/orientation")
      |> halt()
```

New:
```elixir
      conn
      |> put_flash(:error, "Please complete onboarding first.")
      |> redirect(to: ~p"/onboarding")
      |> halt()
```

- [ ] **Step 2: Update the router**

In `lib/grateful_set_crew_web/router.ex`, replace the orientation scope block (lines 98-103):

Old:
```elixir
  ## Orientation routes (crew only, not yet complete)
  scope "/orientation", GratefulSetCrewWeb do
    pipe_through [:browser, :require_crew, :require_orientation_incomplete]

    live "/", OrientationLive.Index, :index
  end
```

New:
```elixir
  ## Onboarding routes (crew only, not yet complete)
  scope "/onboarding", GratefulSetCrewWeb do
    pipe_through [:browser, :require_crew, :require_orientation_incomplete]

    live "/", OnboardingLive, :index
  end
```

- [ ] **Step 3: Run existing tests to confirm no regression**

```bash
cd grateful_set_crew && mix test test/grateful_set_crew_web/user_auth_test.exs
```

Expected: All pass (the redirect destination changed but no auth logic changed).

- [ ] **Step 4: Commit**

```bash
git add lib/grateful_set_crew_web/user_auth.ex \
        lib/grateful_set_crew_web/router.ex
git commit -m "feat: update orientation routes to /onboarding"
```

---

## Task 4: OnboardingLive — Write Failing Tests

**Files:**
- Create: `test/grateful_set_crew_web/live/onboarding_live_test.exs`

- [ ] **Step 1: Create the LiveView test file**

Create `test/grateful_set_crew_web/live/onboarding_live_test.exs`:

```elixir
defmodule GratefulSetCrewWeb.OnboardingLiveTest do
  use GratefulSetCrewWeb.ConnCase

  import Phoenix.LiveViewTest

  alias GratefulSetCrew.{Accounts, Orientation}

  setup do
    user = crew_user_fixture()
    %{conn: log_in_user(build_conn(), user), user: user}
  end

  describe "mount" do
    test "redirects completed user to dashboard", %{user: user} do
      {:ok, progress} = Orientation.create_progress(user.id)
      {:ok, _} = Orientation.complete_onboarding(progress, 10)
      Accounts.update_user_onboarding_status(user.id, "complete")
      user = Accounts.get_user!(user.id)
      conn = log_in_user(build_conn(), user)

      assert {:error, {:redirect, %{to: "/crew/dashboard"}}} = live(conn, ~p"/onboarding")
    end

    test "new user starts at skills step", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/onboarding")
      assert html =~ "Select Your Skills"
    end

    test "user with saved progress resumes at saved step", %{user: user, conn: conn} do
      {:ok, progress} = Orientation.create_progress(user.id)
      Orientation.save_skills(progress, %{
        selected_skills: ["Stage Hand"],
        current_step: "modules"
      })

      {:ok, _lv, html} = live(conn, ~p"/onboarding")
      assert html =~ "Education Modules"
    end
  end

  describe "Skills step" do
    test "displays skills and certifications", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/onboarding")
      assert html =~ "Stage Hand"
      assert html =~ "AV Tech"
      assert html =~ "OSHA 10"
      assert html =~ "Forklift Certified"
    end

    test "continue button is disabled with no skills selected", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/onboarding")
      assert html =~ ~r/disabled/
    end

    test "toggling a skill enables the continue button", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/onboarding")
      html = render_click(lv, "toggle_skill", %{"skill" => "Stage Hand"})
      refute html =~ ~r/phx-click="continue_skills"[^>]*disabled/
    end

    test "shows error when continuing with no skill selected", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/onboarding")
      html = render_click(lv, "continue_skills", %{})
      assert html =~ "Please select at least one skill"
    end

    test "advances to modules step after selecting skill and continuing", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/onboarding")
      render_click(lv, "toggle_skill", %{"skill" => "Stage Hand"})
      html = render_click(lv, "continue_skills", %{})
      assert html =~ "Education Modules"
    end

    test "persists skills to database", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/onboarding")
      render_click(lv, "toggle_skill", %{"skill" => "AV Tech"})
      render_click(lv, "continue_skills", %{})

      progress = Orientation.get_progress(user.id)
      assert "AV Tech" in progress.selected_skills
      assert progress.current_step == "modules"
    end
  end

  describe "Modules step" do
    setup %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/onboarding")
      render_click(lv, "toggle_skill", %{"skill" => "Stage Hand"})
      render_click(lv, "continue_skills", %{})
      %{lv: lv, user: user}
    end

    test "displays all 5 modules", %{lv: lv} do
      html = render(lv)
      assert html =~ "Welcome &amp; GSC Mission"
      assert html =~ "Safety Protocols"
      assert html =~ "Full Rulebook Review"
      assert html =~ "Positions &amp; Chain of Command"
      assert html =~ "Uniform Standards"
    end

    test "shows YouTube embeds for modules with video_id", %{lv: lv} do
      html = render(lv)
      assert html =~ "youtube.com/embed/sCpHVSrcPXc"
      assert html =~ "youtube.com/embed/MMGWmo9wCEo"
    end

    test "continue button disabled until all modules complete", %{lv: lv} do
      html = render(lv)
      assert html =~ ~r/phx-click="continue_modules"[^>]*disabled/
    end

    test "marking all modules and checking rulebook enables continue", %{lv: lv} do
      for id <- 1..5 do
        render_click(lv, "mark_module_complete", %{"id" => "#{id}"})
      end
      html = render_click(lv, "toggle_rulebook", %{})
      refute html =~ ~r/phx-click="continue_modules"[^>]*disabled/
    end

    test "shows error if continuing without completing all modules", %{lv: lv} do
      html = render_click(lv, "continue_modules", %{})
      assert html =~ "Please complete all 5 modules"
    end

    test "shows error if continuing without rulebook", %{lv: lv} do
      for id <- 1..5, do: render_click(lv, "mark_module_complete", %{"id" => "#{id}"})
      html = render_click(lv, "continue_modules", %{})
      assert html =~ "Please confirm you have read"
    end

    test "advances to quiz after completing all modules + rulebook", %{lv: lv} do
      for id <- 1..5, do: render_click(lv, "mark_module_complete", %{"id" => "#{id}"})
      render_click(lv, "toggle_rulebook", %{})
      html = render_click(lv, "continue_modules", %{})
      assert html =~ "Question 1 of 10"
    end
  end

  describe "Quiz step" do
    setup %{conn: conn, user: user} do
      {:ok, progress} = Orientation.create_progress(user.id)
      Orientation.save_skills(progress, %{selected_skills: ["Stage Hand"], current_step: "modules"})
      progress = Orientation.get_progress(user.id)
      Orientation.save_modules(progress, %{
        modules_completed: [1, 2, 3, 4, 5],
        rulebook_read: true,
        current_step: "quiz"
      })

      {:ok, lv, html} = live(conn, ~p"/onboarding")
      %{lv: lv, html: html, user: user}
    end

    test "shows first question", %{html: html} do
      assert html =~ "Question 1 of 10"
    end

    test "shows 4 answer options", %{html: html} do
      assert html =~ ~r/phx-value-answer="0"/
      assert html =~ ~r/phx-value-answer="1"/
      assert html =~ ~r/phx-value-answer="2"/
      assert html =~ ~r/phx-value-answer="3"/
    end

    test "answering shows feedback state", %{lv: lv} do
      html = render_click(lv, "answer_question", %{"answer" => "0"})
      assert html =~ "Correct!" or html =~ "Incorrect"
    end

    test "auto-advances to next question after feedback", %{lv: lv} do
      render_click(lv, "answer_question", %{"answer" => "0"})
      send(lv.pid, {:advance_quiz, 1})
      html = render(lv)
      assert html =~ "Question 2 of 10"
    end

    test "shows score after all 10 questions answered and advanced", %{lv: lv} do
      # Answer all 10 questions
      for i <- 1..10 do
        render_click(lv, "answer_question", %{"answer" => "0"})
        send(lv.pid, {:advance_quiz, i})
        render(lv)
      end

      html = render(lv)
      assert html =~ "/10"
    end

    test "passing score advances to complete step", %{lv: lv, user: user} do
      # Correct answers: Q1=0, Q2=1, Q3=2, Q4=3, Q5=2, Q6=1, Q7=2, Q8=2, Q9=2, Q10=3
      correct = [0, 1, 2, 3, 2, 1, 2, 2, 2, 3]

      for {answer, i} <- Enum.with_index(correct, 1) do
        render_click(lv, "answer_question", %{"answer" => "#{answer}"})
        send(lv.pid, {:advance_quiz, i})
        render(lv)
      end

      html = render(lv)
      assert html =~ "You passed" or html =~ "Welcome to the Network"

      user = Accounts.get_user!(user.id)
      assert user.onboarding_status == "complete"
    end

    test "failing score shows retake option", %{lv: lv} do
      # All wrong answers (0 for questions where correct is not 0)
      for i <- 1..10 do
        render_click(lv, "answer_question", %{"answer" => "3"})
        send(lv.pid, {:advance_quiz, i})
        render(lv)
      end

      html = render(lv)
      assert html =~ "8/10 to pass" or html =~ "Retake"
    end

    test "retake resets quiz to question 1", %{lv: lv} do
      for i <- 1..10 do
        render_click(lv, "answer_question", %{"answer" => "3"})
        send(lv.pid, {:advance_quiz, i})
        render(lv)
      end

      html = render_click(lv, "retake_quiz", %{})
      assert html =~ "Question 1 of 10"
    end
  end

  describe "Completion step" do
    test "shows completion message", %{conn: conn, user: user} do
      {:ok, progress} = Orientation.create_progress(user.id)
      Orientation.save_skills(progress, %{selected_skills: ["Stage Hand"], current_step: "modules"})
      progress = Orientation.get_progress(user.id)
      Orientation.save_modules(progress, %{
        modules_completed: [1, 2, 3, 4, 5],
        rulebook_read: true,
        current_step: "quiz"
      })
      progress = Orientation.get_progress(user.id)
      Orientation.complete_onboarding(progress, 9)
      Accounts.update_user_onboarding_status(user.id, "complete")
      user = Accounts.get_user!(user.id)
      conn = log_in_user(build_conn(), user)

      # Completed user should be redirected to dashboard
      assert {:error, {:redirect, %{to: "/crew/dashboard"}}} = live(conn, ~p"/onboarding")
    end
  end

  # Helpers

  defp crew_user_fixture do
    {:ok, user} = Accounts.register_user(%{
      email: "crew#{System.unique_integer()}@example.com",
      role: "crew"
    })
    user
  end
end
```

- [ ] **Step 2: Run to verify tests fail**

```bash
cd grateful_set_crew && mix test test/grateful_set_crew_web/live/onboarding_live_test.exs
```

Expected: Compilation errors — `OnboardingLive` does not exist yet.

- [ ] **Step 3: Commit the test file**

```bash
git add test/grateful_set_crew_web/live/onboarding_live_test.exs
git commit -m "test: add failing tests for OnboardingLive"
```

---

## Task 5: OnboardingLive — Implementation

**Files:**
- Create: `lib/grateful_set_crew_web/live/onboarding_live.ex`

- [ ] **Step 1: Create the OnboardingLive file**

Create `lib/grateful_set_crew_web/live/onboarding_live.ex` with the full implementation:

```elixir
defmodule GratefulSetCrewWeb.OnboardingLive do
  use GratefulSetCrewWeb, :live_view

  on_mount {GratefulSetCrewWeb.UserAuth, :ensure_current_scope}

  alias GratefulSetCrew.{Accounts, Orientation}
  alias GratefulSetCrew.Orientation.Progress

  @skills_list [
    "Stage Hand", "AV Tech", "Lighting Tech", "Rigger", "Camera Assist",
    "FOH Audio", "Monitor Engineer", "Spotlight Op", "Carpenter", "Forklift Op",
    "LED Wall Tech", "Video Director"
  ]

  @certifications_list [
    "OSHA 10", "OSHA 30", "Forklift Certified", "First Aid/CPR",
    "Rigging Certified", "Electrical License"
  ]

  @modules_list [
    %{id: 1, title: "Welcome & GSC Mission", video_id: "sCpHVSrcPXc"},
    %{id: 2, title: "Safety Protocols & Stop-Work Authority", video_id: "MMGWmo9wCEo"},
    %{id: 3, title: "Full Rulebook Review", video_id: nil},
    %{id: 4, title: "Positions & Chain of Command (01-15)", video_id: nil},
    %{id: 5, title: "Uniform Standards, Strikes & Pay Rules", video_id: nil}
  ]

  @quiz_questions [
    %{
      question: "What is Stop-Work Authority?",
      options: [
        "The right of any crew member to halt work due to an unsafe condition",
        "A management directive to pause operations for scheduling",
        "A client's power to cancel a confirmed job",
        "A written form submitted after a safety incident"
      ],
      correct: 0
    },
    %{
      question: "Which of the following best describes GSC's mission?",
      options: [
        "To provide the lowest-cost labor to event clients",
        "To connect skilled live event professionals with quality work and fair pay",
        "To manage venues and event logistics end-to-end",
        "To train and certify workers in audio-visual skills"
      ],
      correct: 1
    },
    %{
      question: "What should you do if you witness an unsafe working condition on-site?",
      options: [
        "Finish the task and report it in your post-job review",
        "Only report it if you are personally injured",
        "Invoke Stop-Work Authority and notify your GSC Lead immediately",
        "Continue working and inform the venue staff"
      ],
      correct: 2
    },
    %{
      question: "What is the minimum advance notice required when you cannot make a confirmed job?",
      options: [
        "No notice required — just don't show up",
        "At least 1 hour before call time",
        "At least 4 hours before call time",
        "At least 24 hours before call time"
      ],
      correct: 3
    },
    %{
      question: "Who is your primary point of contact during an active job?",
      options: [
        "The venue's event coordinator",
        "GratefulSetCrew phone support",
        "The GSC Lead assigned to the event",
        "The client who posted the job"
      ],
      correct: 2
    },
    %{
      question: "What is the GSC standard dress code for crew members on-site?",
      options: [
        "Jeans and any dark top",
        "All-black professional attire per the GSC Uniform Standards",
        "Hi-vis vest over any clothing",
        "Business casual — slacks and a button-up shirt"
      ],
      correct: 1
    },
    %{
      question: "What happens if you receive a Strike under GSC policy?",
      options: [
        "Nothing — strikes are informal warnings only",
        "You are automatically removed from the network",
        "It is recorded and tracked; three strikes can result in removal",
        "Your pay for that job is withheld"
      ],
      correct: 2
    },
    %{
      question: "How are crew member payments processed through GSC?",
      options: [
        "Cash on site from the client at job completion",
        "Check mailed to your address within 30 days",
        "Via Stripe transfer to your connected bank account",
        "PayPal within 48 hours of job completion"
      ],
      correct: 2
    },
    %{
      question: "What does it mean to hold 'Position 01' on a GSC event?",
      options: [
        "You are the first crew member to arrive on site",
        "You are the GSC Lead responsible for the crew department",
        "You operate the primary AV system",
        "You are assigned to load-in only"
      ],
      correct: 1
    },
    %{
      question: "When are crew members eligible to receive dispatch offers?",
      options: [
        "Immediately after creating an account",
        "After setting up a Stripe account",
        "After completing 3 trial jobs",
        "After completing onboarding and being approved"
      ],
      correct: 3
    }
  ]

  @step_order [:skills, :modules, :quiz, :complete]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user

    progress =
      case Orientation.get_progress(user.id) do
        nil ->
          {:ok, p} = Orientation.create_progress(user.id)
          p

        p ->
          p
      end

    if Orientation.is_complete?(progress) do
      {:ok, push_navigate(socket, to: ~p"/crew/dashboard")}
    else
      quiz_progress = %{
        current_question: 0,
        answers: [],
        score: nil,
        attempts: progress.quiz_attempts || 0,
        finished: false,
        showing_feedback: false,
        last_answer_correct: nil
      }

      socket =
        socket
        |> assign(:progress, progress)
        |> assign(:current_step, String.to_atom(progress.current_step))
        |> assign(:selected_skills, progress.selected_skills || [])
        |> assign(:selected_certifications, progress.selected_certifications || [])
        |> assign(:modules_completed, progress.modules_completed || [])
        |> assign(:rulebook_read, progress.rulebook_read || false)
        |> assign(:quiz_progress, quiz_progress)
        |> assign(:skills_error, nil)
        |> assign(:modules_error, nil)
        |> assign(:save_error, nil)

      {:ok, socket}
    end
  end

  # ---- Skills step events ----

  @impl true
  def handle_event("toggle_skill", %{"skill" => skill}, socket) do
    selected = socket.assigns.selected_skills
    updated = if skill in selected, do: List.delete(selected, skill), else: [skill | selected]
    {:noreply, assign(socket, selected_skills: updated, skills_error: nil)}
  end

  @impl true
  def handle_event("toggle_certification", %{"cert" => cert}, socket) do
    selected = socket.assigns.selected_certifications
    updated = if cert in selected, do: List.delete(selected, cert), else: [cert | selected]
    {:noreply, assign(socket, selected_certifications: updated)}
  end

  @impl true
  def handle_event("continue_skills", _params, socket) do
    if Enum.empty?(socket.assigns.selected_skills) do
      {:noreply, assign(socket, skills_error: "Please select at least one skill to continue.")}
    else
      case Orientation.save_skills(socket.assigns.progress, %{
             selected_skills: socket.assigns.selected_skills,
             selected_certifications: socket.assigns.selected_certifications,
             current_step: "modules"
           }) do
        {:ok, updated_progress} ->
          {:noreply,
           socket
           |> assign(:progress, updated_progress)
           |> assign(:current_step, :modules)}

        {:error, _} ->
          {:noreply, assign(socket, save_error: "Failed to save progress. Please try again.")}
      end
    end
  end

  # ---- Modules step events ----

  @impl true
  def handle_event("mark_module_complete", %{"id" => id_str}, socket) do
    module_id = String.to_integer(id_str)
    completed = socket.assigns.modules_completed
    updated = if module_id in completed, do: completed, else: [module_id | completed]
    {:noreply, assign(socket, modules_completed: updated)}
  end

  @impl true
  def handle_event("toggle_rulebook", _params, socket) do
    {:noreply, assign(socket, rulebook_read: !socket.assigns.rulebook_read, modules_error: nil)}
  end

  @impl true
  def handle_event("continue_modules", _params, socket) do
    completed = socket.assigns.modules_completed
    all_module_ids = Enum.map(@modules_list, & &1.id)
    all_done = Enum.all?(all_module_ids, &(&1 in completed))

    cond do
      not all_done ->
        {:noreply, assign(socket, modules_error: "Please complete all 5 modules before continuing.")}

      not socket.assigns.rulebook_read ->
        {:noreply,
         assign(socket, modules_error: "Please confirm you have read the GSC Rulebook.")}

      true ->
        case Orientation.save_modules(socket.assigns.progress, %{
               modules_completed: completed,
               rulebook_read: true,
               current_step: "quiz"
             }) do
          {:ok, updated_progress} ->
            {:noreply,
             socket
             |> assign(:progress, updated_progress)
             |> assign(:current_step, :quiz)}

          {:error, _} ->
            {:noreply, assign(socket, save_error: "Failed to save progress. Please try again.")}
        end
    end
  end

  # ---- Quiz step events ----

  @impl true
  def handle_event("answer_question", %{"answer" => answer_str}, socket) do
    answer_idx = String.to_integer(answer_str)
    quiz = socket.assigns.quiz_progress
    question = Enum.at(@quiz_questions, quiz.current_question)
    is_correct = answer_idx == question.correct
    answers = quiz.answers ++ [answer_idx]

    Process.send_after(self(), {:advance_quiz, length(answers)}, 900)

    {:noreply,
     assign(socket,
       quiz_progress: %{quiz | answers: answers, showing_feedback: true, last_answer_correct: is_correct}
     )}
  end

  @impl true
  def handle_event("retake_quiz", _params, socket) do
    quiz = socket.assigns.quiz_progress

    {:noreply,
     assign(socket,
       quiz_progress: %{quiz |
         current_question: 0,
         answers: [],
         score: nil,
         finished: false,
         showing_feedback: false,
         last_answer_correct: nil
       }
     )}
  end

  @impl true
  def handle_info({:advance_quiz, answered_count}, socket) do
    quiz = socket.assigns.quiz_progress

    if length(quiz.answers) != answered_count do
      {:noreply, socket}
    else
      next_q = quiz.current_question + 1

      if next_q >= 10 do
        score = calculate_score(quiz.answers)

        if score >= 8 do
          case Orientation.complete_onboarding(socket.assigns.progress, score) do
            {:ok, updated_progress} ->
              Accounts.update_user_onboarding_status(socket.assigns.progress.user_id, "complete")

              Phoenix.PubSub.broadcast(
                GratefulSetCrew.PubSub,
                "crew:status_changed",
                {:crew_status_changed, socket.assigns.progress.user_id}
              )

              Process.send_after(self(), :redirect_to_dashboard, 2000)

              {:noreply,
               socket
               |> assign(:progress, updated_progress)
               |> assign(:current_step, :complete)
               |> assign(:quiz_progress, %{quiz | score: score, finished: true, showing_feedback: false})}

            {:error, _} ->
              {:noreply, assign(socket, save_error: "Failed to save. Please try again.")}
          end
        else
          case Orientation.increment_quiz_attempts(socket.assigns.progress, score) do
            {:ok, updated_progress} ->
              {:noreply,
               socket
               |> assign(:progress, updated_progress)
               |> assign(
                 :quiz_progress,
                 %{quiz | score: score, finished: true, showing_feedback: false}
               )}

            {:error, _} ->
              {:noreply, assign(socket, save_error: "Failed to save. Please try again.")}
          end
        end
      else
        {:noreply,
         assign(socket,
           quiz_progress: %{quiz |
             current_question: next_q,
             showing_feedback: false,
             last_answer_correct: nil
           }
         )}
      end
    end
  end

  @impl true
  def handle_info(:redirect_to_dashboard, socket) do
    {:noreply, push_navigate(socket, to: ~p"/crew/dashboard")}
  end

  defp calculate_score(answers) do
    @quiz_questions
    |> Enum.zip(answers)
    |> Enum.count(fn {q, a} -> q.correct == a end)
  end

  # ---- Rendering ----

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-slate-900">
      <div class="border-b border-slate-900">
        <div class="mx-auto max-w-2xl px-6 py-6">
          <h1 class="text-xl font-bold text-white mb-4">Crew Onboarding</h1>
          <.step_bar current_step={@current_step} />
        </div>
      </div>

      <%= if @save_error do %>
        <div class="mx-auto max-w-2xl px-6 pt-4">
          <div class="bg-red-900/50 border border-red-500 rounded-lg px-4 py-3 text-red-300 text-sm">
            <%= @save_error %>
          </div>
        </div>
      <% end %>

      <div class="mx-auto max-w-2xl px-6 py-8">
        <%= case @current_step do %>
          <% :skills -> %>
            <.skills_step
              selected_skills={@selected_skills}
              selected_certifications={@selected_certifications}
              error={@skills_error}
            />
          <% :modules -> %>
            <.modules_step
              modules_completed={@modules_completed}
              rulebook_read={@rulebook_read}
              error={@modules_error}
            />
          <% :quiz -> %>
            <.quiz_step quiz_progress={@quiz_progress} />
          <% :complete -> %>
            <.complete_step />
        <% end %>
      </div>
    </div>
    """
  end

  # ---- Step bar ----

  defp step_bar(assigns) do
    steps = [{:skills, "1", "Skills"}, {:modules, "2", "Education"}, {:quiz, "3", "Quiz"}, {:complete, "4", "Done"}]
    assigns = assign(assigns, :steps, steps)

    ~H"""
    <div class="flex items-center">
      <%= for {{step, num, label}, idx} <- Enum.with_index(@steps) do %>
        <div class="flex items-center">
          <div class={[
            "flex items-center gap-2",
            if(step_reached?(@current_step, step), do: "text-orange-400", else: "text-slate-500")
          ]}>
            <span class={[
              "h-7 w-7 rounded-full flex items-center justify-center text-xs font-bold border",
              cond do
                @current_step == step ->
                  "bg-orange-500 border-orange-500 text-white"
                step_passed?(@current_step, step) ->
                  "bg-green-600 border-green-600 text-white"
                true ->
                  "bg-transparent border-slate-600 text-slate-500"
              end
            ]}>
              <%= if step_passed?(@current_step, step), do: "✓", else: num %>
            </span>
            <span class="text-sm font-medium hidden sm:inline"><%= label %></span>
          </div>
          <%= if idx < 3 do %>
            <div class="mx-3 h-px w-6 sm:w-12 bg-slate-600"></div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  # ---- Skills step ----

  defp skills_step(assigns) do
    assigns =
      assigns
      |> assign(:all_skills, @skills_list)
      |> assign(:all_certifications, @certifications_list)

    ~H"""
    <div class="bg-slate-900 rounded-xl p-8 shadow-xl">
      <h2 class="text-2xl font-bold text-white mb-2">Select Your Skills & Qualifications</h2>
      <p class="text-slate-400 mb-8">Choose the skills you can perform and any certifications you hold.</p>

      <%= if @error do %>
        <div class="mb-6 bg-red-900/50 border border-red-500 rounded-lg px-4 py-3 text-red-300 text-sm">
          <%= @error %>
        </div>
      <% end %>

      <div class="mb-8">
        <h3 class="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-3">Job Skills</h3>
        <div class="flex flex-wrap gap-2">
          <%= for skill <- @all_skills do %>
            <button
              phx-click="toggle_skill"
              phx-value-skill={skill}
              class={[
                "px-4 py-2 rounded-full text-sm font-medium border transition-all",
                if(skill in @selected_skills,
                  do: "bg-orange-500 border-orange-500 text-white",
                  else: "border-slate-600 text-slate-300 hover:border-orange-400 hover:text-orange-400"
                )
              ]}
            >
              <%= skill %>
            </button>
          <% end %>
        </div>
      </div>

      <div class="mb-8">
        <h3 class="text-xs font-semibold text-slate-400 uppercase tracking-wider mb-3">Certifications <span class="text-slate-500 normal-case">(optional)</span></h3>
        <div class="flex flex-wrap gap-2">
          <%= for cert <- @all_certifications do %>
            <button
              phx-click="toggle_certification"
              phx-value-cert={cert}
              class={[
                "px-4 py-2 rounded-full text-sm font-medium border transition-all",
                if(cert in @selected_certifications,
                  do: "bg-blue-600 border-blue-600 text-white",
                  else: "border-slate-600 text-slate-300 hover:border-blue-400 hover:text-blue-400"
                )
              ]}
            >
              <%= cert %>
            </button>
          <% end %>
        </div>
      </div>

      <button
        phx-click="continue_skills"
        disabled={Enum.empty?(@selected_skills)}
        class={[
          "w-full py-3 rounded-lg font-semibold text-white transition-all",
          if(Enum.empty?(@selected_skills),
            do: "bg-slate-600 cursor-not-allowed opacity-50",
            else: "bg-orange-500 hover:bg-orange-600"
          )
        ]}
      >
        Continue to Education Modules →
      </button>
    </div>
    """
  end

  # ---- Modules step ----

  defp modules_step(assigns) do
    assigns = assign(assigns, :all_modules, @modules_list)

    ~H"""
    <div class="bg-slate-900 rounded-xl p-8 shadow-xl">
      <h2 class="text-2xl font-bold text-white mb-2">Education Modules</h2>
      <p class="text-slate-400 mb-2">
        Complete all 5 modules and confirm you have read the GSC Rulebook.
      </p>
      <p class="text-sm text-slate-500 mb-8">
        <%= Enum.count(@modules_completed) %> of 5 modules completed
      </p>

      <%= if @error do %>
        <div class="mb-6 bg-red-900/50 border border-red-500 rounded-lg px-4 py-3 text-red-300 text-sm">
          <%= @error %>
        </div>
      <% end %>

      <div class="space-y-4 mb-8">
        <%= for mod <- @all_modules do %>
          <% done = mod.id in @modules_completed %>
          <div class={[
            "rounded-lg border-2 overflow-hidden transition-all",
            if(done, do: "border-green-600", else: "border-slate-700")
          ]}>
            <div class="flex items-center justify-between px-5 py-4">
              <div class="flex items-center gap-3">
                <span class={[
                  "h-7 w-7 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0",
                  if(done, do: "bg-green-600 text-white", else: "bg-slate-700 text-slate-400")
                ]}>
                  <%= if done, do: "✓", else: mod.id %>
                </span>
                <span class={["font-medium", if(done, do: "text-green-400", else: "text-white")]}>
                  <%= mod.title %>
                </span>
              </div>
              <%= if not done do %>
                <button
                  phx-click="mark_module_complete"
                  phx-value-id={"#{mod.id}"}
                  class="text-sm px-4 py-1.5 rounded bg-slate-700 text-slate-300 hover:bg-slate-600 transition-colors flex-shrink-0"
                >
                  Mark Complete
                </button>
              <% else %>
                <span class="text-green-500 text-sm font-medium">Done</span>
              <% end %>
            </div>

            <%= if mod.video_id != nil and not done do %>
              <div class="border-t border-slate-700">
                <iframe
                  width="100%"
                  height="280"
                  src={"https://www.youtube.com/embed/#{mod.video_id}"}
                  title={mod.title}
                  frameborder="0"
                  allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                  allowfullscreen
                ></iframe>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <div class="mb-8 bg-slate-700/50 rounded-lg p-4">
        <label class="flex items-start gap-3 cursor-pointer">
          <input
            type="checkbox"
            checked={@rulebook_read}
            phx-click="toggle_rulebook"
            class="mt-1 h-4 w-4 rounded border-slate-500 bg-slate-700 text-orange-500 focus:ring-orange-500"
          />
          <span class="text-slate-300 text-sm">
            I have read and understood the full GSC Rulebook
          </span>
        </label>
      </div>

      <button
        phx-click="continue_modules"
        disabled={Enum.count(@modules_completed) < 5 or not @rulebook_read}
        class={[
          "w-full py-3 rounded-lg font-semibold text-white transition-all",
          if(Enum.count(@modules_completed) < 5 or not @rulebook_read,
            do: "bg-slate-600 cursor-not-allowed opacity-50",
            else: "bg-orange-500 hover:bg-orange-600"
          )
        ]}
      >
        Continue to Quiz →
      </button>
    </div>
    """
  end

  # ---- Quiz step ----

  defp quiz_step(assigns) do
    assigns = assign(assigns, :questions, @quiz_questions)

    ~H"""
    <div class="bg-slate-900 rounded-xl p-8 shadow-xl">
      <%= if @quiz_progress.finished do %>
        <.quiz_results quiz_progress={@quiz_progress} />
      <% else %>
        <.quiz_question
          quiz_progress={@quiz_progress}
          questions={@questions}
        />
      <% end %>
    </div>
    """
  end

  defp quiz_question(assigns) do
    ~H"""
    <% q_idx = @quiz_progress.current_question %>
    <% question = Enum.at(@questions, q_idx) %>
    <% answered = @quiz_progress.showing_feedback %>

    <div class="mb-2 text-sm font-medium text-slate-400">
      Question <%= q_idx + 1 %> of 10
    </div>
    <div class="w-full bg-slate-700 rounded-full h-1.5 mb-6">
      <div
        class="bg-orange-500 h-1.5 rounded-full transition-all"
        style={"width: #{(q_idx / 10) * 100}%"}
      ></div>
    </div>

    <h3 class="text-lg font-semibold text-white mb-6"><%= question.question %></h3>

    <div class="space-y-3">
      <%= for {option, idx} <- Enum.with_index(question.options) do %>
        <% is_selected = answered and List.last(@quiz_progress.answers) == idx %>
        <% is_correct_answer = idx == question.correct %>
        <button
          phx-click={if(not answered, do: "answer_question")}
          phx-value-answer={"#{idx}"}
          disabled={answered}
          class={[
            "w-full text-left px-5 py-3.5 rounded-lg border transition-all text-sm",
            cond do
              answered and is_correct_answer ->
                "bg-green-900/50 border-green-500 text-green-300"
              answered and is_selected and not is_correct_answer ->
                "bg-red-900/50 border-red-500 text-red-300"
              answered ->
                "border-slate-700 text-slate-500 opacity-50"
              true ->
                "border-slate-600 text-slate-300 hover:border-orange-400 hover:text-white cursor-pointer"
            end
          ]}
        >
          <span class="font-medium mr-2"><%= to_string([?A + idx]) %>.</span>
          <%= option %>
        </button>
      <% end %>
    </div>

    <%= if answered do %>
      <p class={[
        "mt-4 text-sm font-medium",
        if(@quiz_progress.last_answer_correct, do: "text-green-400", else: "text-red-400")
      ]}>
        <%= if @quiz_progress.last_answer_correct, do: "Correct!", else: "Incorrect" %>
        Moving to next question...
      </p>
    <% end %>
    """
  end

  defp quiz_results(assigns) do
    ~H"""
    <div class="text-center">
      <div class="text-6xl font-bold mb-2">
        <span class={if @quiz_progress.score >= 8, do: "text-green-400", else: "text-red-400"}>
          <%= @quiz_progress.score %>
        </span>
        <span class="text-slate-500">/10</span>
      </div>

      <%= if @quiz_progress.score >= 8 do %>
        <div class="mt-4 mb-6">
          <p class="text-xl font-semibold text-green-400">You passed!</p>
          <p class="text-slate-400 mt-2">You're now dispatch eligible. Redirecting to your dashboard...</p>
        </div>
        <a href={~p"/crew/dashboard"} class="inline-block bg-orange-500 hover:bg-orange-600 text-white font-semibold px-8 py-3 rounded-lg transition-colors">
          Go to Dashboard →
        </a>
      <% else %>
        <div class="mt-4 mb-6">
          <p class="text-xl font-semibold text-red-400">Not quite there yet</p>
          <p class="text-slate-400 mt-2">You need 8/10 to pass. Review the modules and try again.</p>
          <p class="text-slate-500 text-sm mt-1">Attempts: <%= @quiz_progress.attempts %></p>
        </div>
        <button
          phx-click="retake_quiz"
          class="bg-orange-500 hover:bg-orange-600 text-white font-semibold px-8 py-3 rounded-lg transition-colors"
        >
          Retake Quiz
        </button>
      <% end %>
    </div>
    """
  end

  # ---- Complete step ----

  defp complete_step(assigns) do
    ~H"""
    <div class="bg-slate-900 rounded-xl p-8 shadow-xl text-center">
      <div class="text-5xl mb-6">✨</div>
      <h2 class="text-3xl font-bold text-white mb-3">Welcome to the Network</h2>
      <p class="text-slate-400 text-lg mb-8">
        You can now receive dispatch offers.
      </p>
      <a
        href={~p"/crew/dashboard"}
        class="inline-block bg-orange-500 hover:bg-orange-600 text-white font-semibold px-8 py-3 rounded-lg transition-colors"
      >
        Go to Dashboard →
      </a>
    </div>
    """
  end

  # ---- Helpers ----

  defp step_index(step), do: Enum.find_index(@step_order, &(&1 == step))
  defp step_passed?(current, step), do: step_index(current) > step_index(step)
  defp step_reached?(current, step), do: step_index(current) >= step_index(step)
end
```

- [ ] **Step 2: Run the tests**

```bash
cd grateful_set_crew && mix test test/grateful_set_crew_web/live/onboarding_live_test.exs
```

Expected: Most tests pass. If any fail, examine the output carefully.

Common failure sources:
- HTML entity encoding: `&amp;` in rendered HTML when template has `&` (e.g., "Welcome & GSC Mission" becomes "Welcome &amp; GSC Mission"). Adjust test assertions accordingly.
- Missing `create_progress` call in test setup before navigating — the setup must create a progress record or the LiveView will create one automatically on mount.

- [ ] **Step 3: Run the full test suite**

```bash
cd grateful_set_crew && mix test
```

Expected: Full suite passes (the new route/module is wired up; old orientation tests may need updating — see Task 6).

- [ ] **Step 4: Commit**

```bash
git add lib/grateful_set_crew_web/live/onboarding_live.ex
git commit -m "feat: implement OnboardingLive with skills, modules, quiz, and completion steps"
```

---

## Task 6: Cleanup Old Orientation LiveView

**Files:**
- Delete: `lib/grateful_set_crew_web/live/orientation_live/index.ex`

- [ ] **Step 1: Delete the old orientation LiveView**

```bash
rm grateful_set_crew/lib/grateful_set_crew_web/live/orientation_live/index.ex
rmdir grateful_set_crew/lib/grateful_set_crew_web/live/orientation_live 2>/dev/null || true
```

- [ ] **Step 2: Verify the app compiles cleanly**

```bash
cd grateful_set_crew && mix compile --warnings-as-errors
```

Expected: Clean compile with no warnings.

- [ ] **Step 3: Run the full test suite**

```bash
cd grateful_set_crew && mix test
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove obsolete OrientationLive.Index"
```

---

## Notes for Implementor

**Migration rollback order:** If `mix ecto.rollback` fails with a "column has dependent objects" error on SQLite, run `mix ecto.reset` in development to start fresh.

**Quiz auto-advance in tests:** The 900ms timer fires `{:advance_quiz, count}` asynchronously. Tests bypass the timer by calling `send(lv.pid, {:advance_quiz, n})` directly — this is by design and safe.

**HTML entity encoding:** LiveView encodes `&` as `&amp;` in rendered HTML. Tests that assert on module titles with `&` must use `&amp;`:
```elixir
assert html =~ "Welcome &amp; GSC Mission"
```

**Redirect for completed users:** The `require_orientation_incomplete` plug blocks completed users from reaching `/onboarding` via the router. The `mount/3` redirect is a second safety net for LiveView navigations.

**PubSub broadcast on completion:** `Orientation.complete_onboarding` saves to DB; the PubSub broadcast in `handle_info({:advance_quiz, ...})` notifies any listeners of the crew status change. This is fire-and-forget — do not await it.
