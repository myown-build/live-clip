defmodule LiveClipWeb.WatcherLive do
  use LiveClipWeb, :live_view

  require Phoenix.Component

  require Logger

  alias LiveClip.Watcher

  alias LiveClipWeb.Endpoint

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col gap-3 bg-neutral-900 text-white/70 p-4">
      
      <div class="w-full flex flex-col items-center bg-neutral-700 p-4 border rounded border-gray-500">
        Supabase connection
        <.supabase id="supabase-watch" auth={%{token: @auth_token}}>
          <:file_upload :if={@upload_params !== nil}>
            <div class="flex flex-col items-center bg-neutral-800 p-3 border-2 rounded">
              <span>Uploading {"#{@upload_params["videoId"]}.mp4"}</span>
              <.form
                for={to_form(@upload_params || %{})}
                id={"supabase_upload-form"}
                phx-change="upload:change"
                phx-submit="upload:submit"
              >
              <%!-- <.live_file_input /> --%>
                <div class="flex flex-row gap-10">
                  <%!-- <.live_file_input upload={@uploads.video} /> --%>
                  
                  <input name="videoId" type="hidden" value={@upload_params["videoId"]} />
                  <input name="video" type="file" accept="*" />
                  <button class="border p-2 rounded border-gray-500 bg-neutral-900 hover:bg-neutral-700" type="submit">Upload</button>
                </div>
              </.form>
            </div>
          </:file_upload>
        </.supabase>
      </div>

      <div class="mt-3 flex flex-row justify-center border rounded border-neutral-600">
        <span :if={@watcher_peer !== nil}>Connect to: {@watcher_peer[:uri]}</span>
        <.form
          :if={@watcher_form !== nil}
          for={@watcher_form}
          id="watcher-form"
          phx-change="watcher:change"
          phx-submit="watcher:connect"
          class="w-1/3 p-4 text-white text-xl font-code align-middle bg-neutral-600"
        >
          <.input field={@watcher_form[:token]} label="Access token" class="rounded-full border-2 border-neutral-800 " autocomplete="off" />
          <button 
            :if={not @is_connected?}
            class="mt-2 border p-2 rounded border-gray-500 bg-neutral-900 hover:bg-neutral-700"
          >Connect</button>
        </.form>
      </div>

      <div :if={@is_connected?}>
        <button
          phx-click={JS.push("clip:new")}
          class="p-2 border border-gray-500 bg-neutral-900 hover:bg-neutral-700"
        >New Clip</button>
      
        <div :for={{id, clip} <- Enum.sort(@clips, :desc)}>
          <span>ID: {inspect(id)}</span>
          <span>{inspect(clip)}</span>
          <button
            phx-click={JS.push("clip:set", value: %{"id" => id})}
            class="p-2 border border-gray-500 bg-neutral-900 hover:bg-neutral-700"
          >Set Clip</button>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(params, session, socket) do
    Logger.info("[demo] sesion: #{inspect(session)}, params: #{inspect(params)}")

    socket = assign(socket, 
      client: nil,
      is_connected?: false,
      watcher_form: nil,
      watcher_peer: nil,
      clip_form: nil,
      clips: %{},
      auth_token: nil,
      user: nil,
      upload_params: nil
    )

    if connected?(socket) do
      socket = assign(socket, watcher_form: new_watcher_form())

      # socket = allow_upload(socket, :video, accept: ~w(.mp4))

      {:ok, socket, layout: false}
    else
      case params["token"] do
        nil ->
          {:ok, socket, layout: false}

        token ->
          socket = put_private(socket, :supabase_auth, %{token: token})
          {:ok, push_navigate(socket, to: ~p"/dev/watch", replace: true)}
      end
    end
  end

  @impl true
  def handle_params(unsigned_params, uri, socket) do
    # unsigned_params, uri, socket
    dbg(uri)
    dbg(unsigned_params)

    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    dbg(msg)
    {:noreply, socket}
  end

  # @impl true
  # def handle_event("auth:success", %{"user" => _user} = _params, socket) do
  #   # Remove the token from the url by pushing a patch with replace.
  #   {:noreply, push_patch(socket, to: ~p"/dev/watch", replace: true)}
  # end

  @impl true
  def handle_event("upload", %{"data" => %{} = data} = params, socket) do
    case data do
      %{"id" => id} ->
        # "2026-04-22T23:17:30Z.mp4" 
        clip_id = Path.basename(params["args"]["name"], ".mp4")
        
        %{clips: clips} = socket.assigns
        dbg(clips)

        clips = put_in(clips[clip_id][:remote], id) 
        socket = assign(socket, clips: clips)
        {:noreply, socket}

      _ ->
        Logger.error("bad upload data response")
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("upload:submit", %{"videoId" => id} = _params, socket) do
    # dbg(params)

    socket = push_event(socket, 
      "supabase:call", 
      %{command: "upload", args: %{
        selector: "video", name: "#{id}.mp4"
      }}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("upload:change", params, socket) do
    dbg(params)

    {:noreply, socket}
  end

  @impl true
  def handle_event("watcher:connect", %{"token" => token}, socket) do
    # dbg(params)
    Logger.debug("Connecting watcher token=#{inspect(token)}")

    {watcher, uri} = Watcher.start_or_fetch_watcher!(token)
    socket = put_private(socket, :watcher, watcher)

    socket = assign(socket,
      watcher_form: nil, 
      is_connected?: true,
      watcher_peer: %{uri: uri},
      # draft_id: id,
      clip_form: to_form(%{"start" => 0, "stop" => 1})
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("watcher:change", %{} = params, socket) do
    watcher_form =
      params
      |> Map.take(["token"])
      |> to_form()

    socket = assign(socket, watcher_form: watcher_form)
    {:noreply, socket}
  end

  @impl true
  def handle_event("clipper:change", %{} = params, socket) do
    clipper_form =
      params
      |> Map.take(["id", "start", "stop"])
      |> to_form()

    socket = assign(socket, clipper_form: clipper_form)
    {:noreply, socket}
  end

  @impl true
  def handle_event("clip:set", %{"id" => id} = _params, socket) do
    socket = 
      socket
      # |> push_event("clip:upload", %{id: id})
      |> assign(upload_params: %{"videoId" => id})

    {:noreply, socket}
  end

  @impl true
  def handle_event("clip:new", %{} = params, socket) do
    dbg(params)

    case socket.private do
      %{watcher: watcher} ->
        id = Watcher.new_clip_id()
        Logger.info("Watcher requesting new clip #{id}")

        %{clips: clips} = socket.assigns

        clips = Map.put(clips, id, %{})
        Watcher.send_message!(watcher, %{changes: %{id => "create"}})

        socket = assign(socket, 
          # clips: clips, file_upload: %{id: id}
          clips: clips, upload_params: %{"videoId" => id}
        )
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    dbg([event, params])

    {:noreply, socket}
  end

  defp new_watcher_form do
    case Mix.env() do
      :dev ->
        to_form(%{"token" => create_token(1)})
        
      _ ->
        to_form(%{"token" => ""})
    end
  end

  def create_token(_user_id) do
    Phoenix.Token.sign(Endpoint, "user auth", 1)
  end
end
