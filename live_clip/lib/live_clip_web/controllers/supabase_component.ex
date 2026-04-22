defmodule LiveClipWeb.Live.SupabaseComponent do
  use LiveClipWeb, :live_component

  alias Phoenix.LiveView.ColocatedHook

  require Logger

  def get_supabase_client() do
    %{
      url: Application.get_env(:live_clip, :supabase_url),
      key: Application.get_env(:live_clip, :supabase_key)
    }
  end

  attr :id, :string, required: true
  
  slot :auth_otp
  slot :status

  @impl true
  def render(assigns) do
    ~H"""
      <div>
        <script :type={ColocatedHook} name=".Supabase">
          import { createClient } from '@supabase/supabase-js'

          export default {
            mounted() {
              console.log(this.el, this.el.dataset);
              
              let {
                supabaseUrl, 
                supabaseKey,
                supabaseAuthToken
              } = this.el.dataset;


              const auth = {is_authenticated: false};

              const supabase = createClient(supabaseUrl, supabaseKey);
              window.supabase = supabase;
              
              supabase.auth
                .getUser()
                .then(({data, error}) => {
                  const {user} = data;

                  if (user.aud == 'authenticated') {
                    this.pushEvent("auth:success", {user});
                  } else if (supabaseAuthToken) {
                    console.log("authenticating using auth token");

                    supabase.auth
                      .verifyOtp({token_hash: supabaseAuthToken, type: 'email'})
                      .then(({data, error}) => {
                        console.log("[supabase.auth] signed in", data, error);
                        this.pushEvent("signInWithOtp", {data, error});
                      });
                  }
                })

              this.handleEvent(
                "supabase:call", 
                async ({command, args}) => {
                  if (command == 'signin') {
                    console.log("supabase.auth.signinOtp", args);

                    let {data, error} = await supabase.auth.signInWithOtp({
                      email: args.email,
                      options: {
                        emailRedirectTo: args.redirect
                      }
                    });
                    this.pushEvent("signInWithOtp", {data, error});
                  }
                }
              );
            }
          }
        </script>
        <div 
          id={"sb_watcher-#{@id}"} 
          phx-hook=".Supabase"
          data-supabase-url={@client.url}
          data-supabase-key={@client.key}
          {@supabase_dataset}
        >
          <%!-- <input :if={@auth !== nil} type="hidden" /> --%>
          <.form
            :if={@auth_status === :unauthenticated and @auth_otp !== nil}
            :let={f}
            for={to_form(@auth_otp_params || %{})}
            id={"#{@id}_auth-form"}
            phx-change="auth:change"
            phx-submit="auth:submit"
            phx-target={@myself}
          >
            {render_slot(@auth_otp, f)}
          </.form>
        </div>
        <%= if @status !== nil and @auth_status in [:authenticating, :email_sent] do %>
          {render_slot(@status, @auth_status)}
        <% end %>
        
        <%!-- {render_slot(@inner_block)} --%>
      </div>
      """
  end

  def mount(%{assigns: assigns} = socket) do
    dbg(assigns)

    dataset = %{}

    dataset = case assigns[:auth_token] do
      nil ->
        dataset
      token ->
        Map.put(dataset, "data-supabase-auth-token", token)
    end

    {auth_otp_params, dataset} = case assigns[:auth_otp] do
      nil ->
        {nil, dataset}
      _ ->
        {
          to_form(%{"email" => ""}), 
          Map.put(dataset, "data-supabase-auth", "email")
        }
    end

    socket = assign(
      socket, 
      client: get_supabase_client(),
      supabase_dataset: dataset,
      auth_otp_params: auth_otp_params,
      auth_status: :unauthenticated
    )

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # dbg(assigns)

    %{supabase_dataset: dataset} = socket.assigns

    dataset = case assigns[:auth_token] do
      nil ->
        dataset
      token ->
        Map.put(dataset, "data-supabase-auth-token", token)
    end

    assigns = Map.put(assigns, :supabase_dataset, dataset)
    socket = assign(socket, assigns)

    {:ok, socket}
  end 

  @impl true
  def handle_event("auth:change", params, socket) do
    socket = assign(socket, auth_otp_params: params)
    {:noreply, socket}
  end

  def handle_event("auth:submit", params, socket) do
    args = Map.take(params, ["email"])

    redirect = LiveClipWeb.Endpoint.url()
    args = Map.put(args, "redirect", redirect)

    socket = 
      socket
      |> assign(auth_status: :authenticating)
      |> push_event("supabase:call", %{command: "signin", args: args})
    
    {:noreply, socket}
  end

  def handle_event("signInWithOtp", params, socket) do
    dbg(params)
    socket = assign(socket, auth_status: :email_sent)
    {:noreply, socket}
  end

  def handle_event(event, params, socket) do
    Logger.error("Unrecognized event #{event}")
    {:noreply, socket}
  end

end