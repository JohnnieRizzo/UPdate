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
end
