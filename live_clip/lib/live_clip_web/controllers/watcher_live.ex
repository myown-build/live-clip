defmodule LiveClipWeb.WatcherLive do
  use LiveClipWeb, :live_view

  require Phoenix.Component

  require Logger

  # alias LiveClipWeb.Endpoint

  def get_supabase_client() do
    %{
      url: Application.get_env(:live_clip, :supabase_url),
      key: Application.get_env(:live_clip, :supabase_key)
    }
  end

  defp get_socket_url() do
    case Mix.env() do
      :dev ->
        "ws://localhost:4001/watcher/websocket"
      
      _ ->
        "wss://myown.build/watcher/websocket"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col gap-3 bg-neutral-900 text-white/70 p-4">
      
      <div class="w-full flex flex-col items-center bg-neutral-700 p-4 border rounded border-gray-500">
        <.supabase id="supabase-watch" auth_token={@auth_token}>

        </.supabase>
        <div :if={@user !== nil} class="flex flex-row items-center gap-4">
          <span>ID: {@user["id"]}</span>
          <span>Email: {@user["email"]}</span>
        </div>
      </div>

      <div :if={@is_connected?}>
        <label id={"drop-zone"}>
          Drop images here, or click to upload.
          <input type="file" id={"file-input"} accept="*" />
        </label>

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
    # dbg(params["token"])

    socket = assign(socket, 
      client: nil,
      is_connected?: false,
      watcher_form: nil,
      clip_form: nil,
      clips: %{},
      auth_token: params["token"],
      user: nil
    )

    if connected?(socket) do
      socket = assign(socket, watcher_form: to_form(%{"token" => ""}))

      {:ok, socket, layout: false}
    else
      {:ok, socket, layout: false}
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

  @impl true
  def handle_event("auth:success", %{"user" => user} = _params, socket) do
    dbg(user)
    socket = put_private(socket, :supabase_auth, user)
    socket = assign(socket, is_connected?: true, user: user)

    # Remove the token from the url by pushing a patch with replace.
    {:noreply, push_patch(socket, to: ~p"/dev/watch", replace: true)}
  end

  def handle_event("watcher:connect", %{"token" => token}, socket) do
    # dbg(params)
    Logger.debug("connecting watcher")

    # %{clips: clips} = socket.assigns

    url = get_socket_url()

    watcher = LiveClip.Watcher.start_or_fetch_watcher!(url, token)
    socket = put_private(socket, :watcher, watcher)
    # dbg(watcher)

    socket = assign(socket,
      watcher_form: nil, 
      is_connected?: true,
      # draft_id: id,
      clip_form: to_form(%{"start" => 0, "stop" => 1})
    )

    {:noreply, socket}
  end

  def handle_event("watcher:change", %{} = params, socket) do
    watcher_form =
      params
      |> Map.take(["token"])
      |> to_form()

    socket = assign(socket, watcher_form: watcher_form)
    {:noreply, socket}
  end

  def handle_event("clipper:change", %{} = params, socket) do
    clipper_form =
      params
      |> Map.take(["id", "start", "stop"])
      |> to_form()

    socket = assign(socket, clipper_form: clipper_form)
    {:noreply, socket}
  end

  def handle_event("clip:set", %{"id" => id} = params, socket) do
    dbg(id)
    socket = push_event(socket, "clip:upload", %{id: id})

    {:noreply, socket}
  end

  def handle_event("clip:new", %{} = params, socket) do
    dbg(params)

    case socket.private do
      %{watcher: watcher} ->
        # id = Ecto.UUID.generate()
        id = 
          :second
          |> DateTime.utc_now() 
          |> to_string()
          |> String.replace(" ", "T")

        %{clips: clips} = socket.assigns

        clips = Map.put(clips, id, params)
        
        LiveClip.Watcher.send_message!(watcher, %{changes: %{id => "create"}})

        socket = assign(socket, clips: clips)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event(event, params, socket) do
    dbg([event, params])

    {:noreply, socket}
  end
end
