defmodule GratefulSetCrewWeb.OnboardingLive do
  use GratefulSetCrewWeb, :live_view

  on_mount {GratefulSetCrewWeb.UserAuth, :ensure_current_scope}

  alias GratefulSetCrew.{Accounts, Orientation}

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
       quiz_progress: %{
         quiz
         | current_question: 0,
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
           quiz_progress: %{
             quiz
             | current_question: next_q,
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
    <div class="min-h-screen bg-[rgb(1,1,1)]">
      <div class="border-b border-zinc-900">
        <div class="mx-auto max-w-2xl px-6 py-6">
          <h1 class="text-sm font-semibold text-[#D4AF37] uppercase tracking-widest mb-4">Crew Onboarding</h1>
          <.step_bar current_step={@current_step} />
        </div>
      </div>

      <%= if @save_error do %>
        <div class="mx-auto max-w-2xl px-6 pt-4">
          <div class="bg-red-950/60 border border-red-800 rounded-lg px-4 py-3 text-red-400 text-sm">
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
    steps = [
      {:skills, "1", "Skills"},
      {:modules, "2", "Education"},
      {:quiz, "3", "Quiz"},
      {:complete, "4", "Done"}
    ]

    assigns = assign(assigns, :steps, steps)

    ~H"""
    <div class="flex items-center">
      <%= for {{step, num, label}, idx} <- Enum.with_index(@steps) do %>
        <div class="flex items-center">
          <div class={[
            "flex items-center gap-2",
            if(step_reached?(@current_step, step), do: "text-[#D4AF37]", else: "text-zinc-600")
          ]}>
            <span class={[
              "h-7 w-7 rounded-full flex items-center justify-center text-xs font-bold border",
              cond do
                @current_step == step ->
                  "bg-[#D4AF37] border-[#D4AF37] text-black"

                step_passed?(@current_step, step) ->
                  "bg-emerald-600 border-emerald-600 text-white"

                true ->
                  "bg-transparent border-zinc-700 text-zinc-600"
              end
            ]}>
              <%= if step_passed?(@current_step, step), do: "✓", else: num %>
            </span>
            <span class="text-sm font-medium hidden sm:inline"><%= label %></span>
          </div>
          <%= if idx < 3 do %>
            <div class="mx-3 h-px w-6 sm:w-12 bg-zinc-800"></div>
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
    <div class="bg-zinc-900 rounded-xl shadow-2xl border border-zinc-800 overflow-hidden">
      <div class="h-0.5 bg-gradient-to-r from-[#D4AF37] via-[#f0d060] to-[#D4AF37]"></div>
      <div class="p-8">
        <h2 class="text-2xl font-bold text-white mb-1">Skills &amp; Qualifications</h2>
        <p class="text-zinc-500 mb-8">Choose the skills you can perform and any certifications you hold.</p>

        <%= if @error do %>
          <div class="mb-6 bg-red-950/60 border border-red-800 rounded-lg px-4 py-3 text-red-400 text-sm">
            <%= @error %>
          </div>
        <% end %>

        <div class="mb-8">
          <h3 class="text-xs font-semibold text-[#D4AF37] uppercase tracking-widest mb-3">Job Skills</h3>
          <div class="flex flex-wrap gap-2">
            <%= for skill <- @all_skills do %>
              <button
                phx-click="toggle_skill"
                phx-value-skill={skill}
                class={[
                  "px-4 py-2 rounded-full text-sm font-medium border transition-all",
                  if(skill in @selected_skills,
                    do: "bg-[#D4AF37] border-[#D4AF37] text-black font-semibold",
                    else: "border-zinc-700 text-zinc-400 hover:border-[#D4AF37] hover:text-[#D4AF37]"
                  )
                ]}
              >
                <%= skill %>
              </button>
            <% end %>
          </div>
        </div>

        <div class="mb-8">
          <h3 class="text-xs font-semibold text-[#D4AF37] uppercase tracking-widest mb-3">
            Certifications <span class="text-zinc-600 normal-case font-normal">(optional)</span>
          </h3>
          <div class="flex flex-wrap gap-2">
            <%= for cert <- @all_certifications do %>
              <button
                phx-click="toggle_certification"
                phx-value-cert={cert}
                class={[
                  "px-4 py-2 rounded-full text-sm font-medium border transition-all",
                  if(cert in @selected_certifications,
                    do: "bg-emerald-600 border-emerald-600 text-white",
                    else: "border-zinc-700 text-zinc-400 hover:border-emerald-500 hover:text-emerald-400"
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
            "w-full py-3 rounded-lg font-semibold transition-all",
            if(Enum.empty?(@selected_skills),
              do: "bg-zinc-800 text-zinc-600 cursor-not-allowed",
              else: "bg-[#D4AF37] text-black hover:bg-[#c9a227]"
            )
          ]}
        >
          Continue to Education Modules →
        </button>
      </div>
    </div>
    """
  end

  # ---- Modules step ----

  defp modules_step(assigns) do
    assigns = assign(assigns, :all_modules, @modules_list)

    ~H"""
    <div class="bg-zinc-900 rounded-xl shadow-2xl border border-zinc-800 overflow-hidden">
      <div class="h-0.5 bg-gradient-to-r from-[#D4AF37] via-[#f0d060] to-[#D4AF37]"></div>
      <div class="p-8">
        <h2 class="text-2xl font-bold text-white mb-1">Education Modules</h2>
        <p class="text-zinc-500 mb-1">Complete all 5 modules and confirm you have read the GSC Rulebook.</p>
        <p class="text-sm text-zinc-600 mb-8">
          <%= Enum.count(@modules_completed) %> of 5 completed
        </p>

        <%= if @error do %>
          <div class="mb-6 bg-red-950/60 border border-red-800 rounded-lg px-4 py-3 text-red-400 text-sm">
            <%= @error %>
          </div>
        <% end %>

        <div class="space-y-3 mb-8">
          <%= for mod <- @all_modules do %>
            <% done = mod.id in @modules_completed %>
            <div class={[
              "rounded-lg border overflow-hidden transition-all",
              if(done, do: "border-emerald-800 bg-emerald-950/30", else: "border-zinc-800 bg-zinc-800/40")
            ]}>
              <div class="flex items-center justify-between px-5 py-4">
                <div class="flex items-center gap-3">
                  <span class={[
                    "h-7 w-7 rounded-full flex items-center justify-center text-xs font-bold flex-shrink-0",
                    if(done, do: "bg-emerald-600 text-white", else: "bg-zinc-700 text-zinc-500")
                  ]}>
                    <%= if done, do: "✓", else: mod.id %>
                  </span>
                  <span class={["font-medium text-sm", if(done, do: "text-emerald-400", else: "text-zinc-200")]}>
                    <%= mod.title %>
                  </span>
                </div>
                <%= if not done do %>
                  <button
                    phx-click="mark_module_complete"
                    phx-value-id={"#{mod.id}"}
                    class="text-xs px-3 py-1.5 rounded border border-zinc-700 text-zinc-400 hover:border-[#D4AF37] hover:text-[#D4AF37] transition-colors flex-shrink-0"
                  >
                    Mark Complete
                  </button>
                <% else %>
                  <span class="text-emerald-500 text-xs font-semibold uppercase tracking-wider">Done</span>
                <% end %>
              </div>

              <%= if mod.video_id != nil and not done do %>
                <div class="border-t border-zinc-800">
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

        <div class="mb-8 bg-zinc-800/40 border border-zinc-800 rounded-lg p-4">
          <label class="flex items-start gap-3 cursor-pointer">
            <input
              type="checkbox"
              checked={@rulebook_read}
              phx-click="toggle_rulebook"
              class="mt-1 h-4 w-4 rounded border-zinc-600 bg-zinc-800 text-[#D4AF37] focus:ring-[#D4AF37]"
            />
            <span class="text-zinc-400 text-sm">
              I have read and understood the full GSC Rulebook
            </span>
          </label>
        </div>

        <button
          phx-click="continue_modules"
          disabled={Enum.count(@modules_completed) < 5 or not @rulebook_read}
          class={[
            "w-full py-3 rounded-lg font-semibold transition-all",
            if(Enum.count(@modules_completed) < 5 or not @rulebook_read,
              do: "bg-zinc-800 text-zinc-600 cursor-not-allowed",
              else: "bg-[#D4AF37] text-black hover:bg-[#c9a227]"
            )
          ]}
        >
          Continue to Quiz →
        </button>
      </div>
    </div>
    """
  end

  # ---- Quiz step ----

  defp quiz_step(assigns) do
    assigns = assign(assigns, :questions, @quiz_questions)

    ~H"""
    <div class="bg-zinc-900 rounded-xl shadow-2xl border border-zinc-800 overflow-hidden">
      <div class="h-0.5 bg-gradient-to-r from-[#D4AF37] via-[#f0d060] to-[#D4AF37]"></div>
      <div class="p-8">
        <%= if @quiz_progress.finished do %>
          <.quiz_results quiz_progress={@quiz_progress} />
        <% else %>
          <.quiz_question quiz_progress={@quiz_progress} questions={@questions} />
        <% end %>
      </div>
    </div>
    """
  end

  defp quiz_question(assigns) do
    ~H"""
    <% q_idx = @quiz_progress.current_question %>
    <% question = Enum.at(@questions, q_idx) %>
    <% answered = @quiz_progress.showing_feedback %>

    <div class="flex items-center justify-between mb-2">
      <span class="text-xs font-semibold text-[#D4AF37] uppercase tracking-widest">
        Question <%= q_idx + 1 %> of 10
      </span>
      <span class="text-xs text-zinc-600"><%= q_idx * 10 %>% complete</span>
    </div>
    <div class="w-full bg-zinc-800 rounded-full h-1 mb-6">
      <div
        class="bg-[#D4AF37] h-1 rounded-full transition-all"
        style={"width: #{(q_idx / 10) * 100}%"}
      ></div>
    </div>

    <h3 class="text-lg font-semibold text-white mb-6 leading-snug"><%= question.question %></h3>

    <div class="space-y-2">
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
                "bg-emerald-950/60 border-emerald-700 text-emerald-300"

              answered and is_selected and not is_correct_answer ->
                "bg-red-950/60 border-red-800 text-red-400"

              answered ->
                "border-zinc-800 text-zinc-600 opacity-40"

              true ->
                "border-zinc-700 text-zinc-300 hover:border-[#D4AF37] hover:text-white cursor-pointer bg-zinc-800/30"
            end
          ]}
        >
          <span class="font-bold mr-2 text-zinc-500"><%= to_string([?A + idx]) %>.</span>
          <%= option %>
        </button>
      <% end %>
    </div>

    <%= if answered do %>
      <p class={[
        "mt-4 text-sm font-medium",
        if(@quiz_progress.last_answer_correct, do: "text-emerald-400", else: "text-red-400")
      ]}>
        <%= if @quiz_progress.last_answer_correct, do: "Correct!", else: "Incorrect —" %>
        Moving to next question...
      </p>
    <% end %>
    """
  end

  defp quiz_results(assigns) do
    ~H"""
    <div class="text-center">
      <div class="text-6xl font-bold mb-2">
        <span class={if @quiz_progress.score >= 8, do: "text-emerald-400", else: "text-red-400"}><%= @quiz_progress.score %></span>
        <span class="text-zinc-700">/10</span>
      </div>

      <%= if @quiz_progress.score >= 8 do %>
        <div class="mt-4 mb-8">
          <p class="text-xl font-semibold text-emerald-400 mb-1">You passed!</p>
          <p class="text-zinc-500 text-sm">
            You're now dispatch eligible. Redirecting to your dashboard...
          </p>
        </div>
        <a
          href={~p"/crew/dashboard"}
          class="inline-block bg-[#D4AF37] hover:bg-[#c9a227] text-black font-semibold px-8 py-3 rounded-lg transition-colors"
        >
          Go to Dashboard →
        </a>
      <% else %>
        <div class="mt-4 mb-8">
          <p class="text-xl font-semibold text-red-400 mb-1">Not quite there yet</p>
          <p class="text-zinc-500 text-sm">You need 8/10 to pass. Review the modules and try again.</p>
          <p class="text-zinc-700 text-xs mt-2">Attempt <%= @quiz_progress.attempts %></p>
        </div>
        <button
          phx-click="retake_quiz"
          class="bg-[#D4AF37] hover:bg-[#c9a227] text-black font-semibold px-8 py-3 rounded-lg transition-colors"
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
    <div class="bg-zinc-900 rounded-xl shadow-2xl border border-zinc-800 overflow-hidden text-center">
      <div class="h-0.5 bg-gradient-to-r from-[#D4AF37] via-[#f0d060] to-[#D4AF37]"></div>
      <div class="p-12">
        <div class="text-5xl mb-6">✦</div>
        <h2 class="text-3xl font-bold text-white mb-2">Welcome to the Network</h2>
        <p class="text-[#D4AF37] text-sm uppercase tracking-widest font-semibold mb-3">Onboarding Complete</p>
        <p class="text-zinc-500 mb-10">You are now eligible to receive dispatch offers.</p>
        <a
          href={~p"/crew/dashboard"}
          class="inline-block bg-[#D4AF37] hover:bg-[#c9a227] text-black font-semibold px-8 py-3 rounded-lg transition-colors"
        >
          Go to Dashboard →
        </a>
      </div>
    </div>
    """
  end

  # ---- Helpers ----

  defp step_index(step), do: Enum.find_index(@step_order, &(&1 == step))
  defp step_passed?(current, step), do: step_index(current) > step_index(step)
  defp step_reached?(current, step), do: step_index(current) >= step_index(step)
end
