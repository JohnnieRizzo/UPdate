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
      for i <- 1..10 do
        render_click(lv, "answer_question", %{"answer" => "0"})
        send(lv.pid, {:advance_quiz, i})
        render(lv)
      end

      html = render(lv)
      assert html =~ "/10"
    end

    test "passing score advances to complete step", %{lv: lv, user: user} do
      # Answers: Q1=0, Q2=1, Q3=2, Q4=3, Q5=2, Q6=1, Q7=2, Q8=2, Q9=1, Q10=3 → 10/10
      correct = [0, 1, 2, 3, 2, 1, 2, 2, 1, 3]

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

      # Completed user should be redirected away from /onboarding
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
