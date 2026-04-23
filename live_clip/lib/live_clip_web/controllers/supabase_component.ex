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
  slot :viewer

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
                supabaseAuthToken,
                supabaseVideoId,
                supabaseUseAuth
              } = this.el.dataset;

              const auth = {is_authenticated: false};

              const supabase = createClient(supabaseUrl, supabaseKey);
              window.supabase = supabase;

              if (supabaseVideoId) {
                const object_name = `${supabaseVideoId}.mp4`;

                let { data } = supabase.storage.from('videos').getPublicUrl(object_name);
                const { publicUrl } = data;

                supabase.storage
                  .from('videos')
                  .exists(object_name)
                  .then(({ data }) => {
                    const exists = (data == true);
                    if (exists) {          
                      this.el.getElementsByTagName('video').src = publicUrl;
                      this.pushEvent("video:src", {exists: true, publicUrl});

                    } else {
                      console.log("Video does not exist.", supabaseVideoId);
                      this.pushEvent("video:src", {exists: false});
                    }
                  });
              }

              if (supabaseUseAuth == "true") {
                supabase.auth
                  .getUser()
                  .then(({data, error}) => {
                    const {user} = data;

                    if (user.aud == 'authenticated') {
                      // this.pushEvent("auth:success", {user});
                      this.pushEventTo(`#${this.el.id}`, "auth:success", {user});
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
              }

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

                  } else if (command == 'upload') {
                    console.log("uploading");

                    const {selector, name} = args; 
                    const input = this.el.getElementsByTagName('input')[selector || 'video'];
                    const {files} = input;

                    if (files && files.length > 0) {
                      console.log("[storage] from(videos) upload", files[0]);
                      // supabase.
                      const { data, error } = await supabase
                        .storage
                        .from('videos')
                        .upload(name, files[0], {
                          // cacheControl: '3600',
                          // upsert: false
                        });
                      console.log("[storage] upload done", data, error);
                      input.value = null;  
                      this.pushEvent("upload", {args, data, error});
                    }
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
          <div :if={@auth_user !== nil} class="flex flex-row items-center gap-4">
            <span>ID: {@auth_user["id"]}</span>
            <span>Email: {@auth_user["email"]}</span>
          </div>
          <.form
            :if={@auth_status === nil and @auth_otp !== nil}
            :let={f}
            for={to_form(@auth_otp_params || %{})}
            id={"#{@id}_auth-form"}
            phx-change="auth:change"
            phx-submit="auth:submit"
            phx-target={@myself}
          >
            {render_slot(@auth_otp, f)}
          </.form>

          <%= if @upload !== nil do %>
            {render_slot(@upload, %{user: @auth_user})}
          <% end %>

          <%= if @viewer !== nil do %>
            {render_slot(@viewer, @viewer_data)}
          <% end %>
        </div>

        <%= if @status !== nil and @auth_status in [:authenticating, :email_sent] do %>
          {render_slot(@status, @auth_status)}
        <% end %>

        <%= if @status !== nil and @auth_status in [:authenticating, :email_sent] do %>
          {render_slot(@status, @auth_status)}
        <% end %>
      
        <%!-- {render_slot(@inner_block)} --%>
      </div>
      """
  end

  @impl true
  def mount(%{assigns: assigns} = socket) do
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
      auth_status: nil,
      auth_user: nil,
      upload_params: %{"name" => ""},
      viewer_data: %{src: nil}
    )

    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    # dbg(assigns)

    %{supabase_dataset: dataset} = socket.assigns

    dataset = 
      [:auth, :video_id, :use_auth]
      |> Stream.map(& {&1, assigns[&1]})
      |> Enum.reduce(dataset, fn 
        {_, nil}, acc ->
          acc

        {:auth, %{token: token}}, acc ->
          Map.put(acc, "data-supabase-auth-token", token)

        {:video_id, video_id}, acc ->
          Map.put(acc, "data-supabase-video-id", video_id)

        {:use_auth, true}, acc ->
          Map.put(acc, "data-supabase-use-auth", "true")

        _, acc ->
          acc
      end)


    dataset = case assigns[:auth_token] do
      nil ->
        dataset
      token ->
        Map.put(dataset, "data-supabase-auth-token", token)
    end

    dataset = case assigns[:video_id] do
      nil ->
        dataset
      video_id ->
        Map.put(dataset, "data-supabase-video-id", video_id)
    end

    assigns = Map.put(assigns, :supabase_dataset, dataset)
    socket = assign(socket, assigns)

    {:ok, socket}
  end 

  @impl true
  def handle_event("auth:success", %{"user" => user} = _params, socket) do
    dbg(user)
    socket = assign(socket, auth_user: user)
    {:noreply, socket}
  end

  @impl true
  def handle_event("auth:change", params, socket) do
    socket = assign(socket, auth_otp_params: params)
    {:noreply, socket}
  end

  @impl true
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

  @impl true
  def handle_event("signInWithOtp", params, socket) do
    dbg(params)
    socket = assign(socket, auth_status: :email_sent)
    {:noreply, socket}
  end

  @impl true
  def handle_event(event, params, socket) do
    Logger.warning("[supabase component] Unrecognized event #{inspect(event)} #{inspect(params)}")
    {:noreply, socket}
  end
end