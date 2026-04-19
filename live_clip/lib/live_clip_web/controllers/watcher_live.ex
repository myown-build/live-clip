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
      
      <button 
        :if={@client === nil}
        phx-click={JS.push("setup:start")}
        class="w-1/3 p-3 border border-gray-500 bg-neutral-900 hover:bg-neutral-700"
      >Connect using Supabase</button>

      <div :if={@client !== nil}>
        <span>Connection to: {@client.url}</span>
        <div 
          id="live-clip-watcher" 
          phx-hook="WatcherHook" 
          phx-change="ignore"
          data-supabase-url={@client.url}
          data-supabase-key={@client.key}
          data-auth-token={@auth_token}
        >
        </div>
      </div>

      <.form
        :if={@watcher_form !== nil}
        for={@watcher_form}
        id="watcher-form"
        phx-change="watcher:change"
        phx-submit="watcher:connect"
        class="w-1/3 p-4 text-white text-xl font-code align-middle bg-neutral-600"
      >
        <.input field={@watcher_form[:token]} label="Access token" class="rounded-full border-2 border-neutral-800 " autocomplete="off" />
        <%!-- <.button>Connect</.button> --%>
        <button 
          :if={not @is_connected?}
          class="mt-2 border p-2 rounded border-gray-500 bg-neutral-900 hover:bg-neutral-700"
        >Connect</button>
      </.form>

      <div :if={@is_connected?}>
<%!--         <.form
          :if={@clip_form !== nil}
          for={@clip_form}
          id="clip-form"
          phx-change="clipper:change"
          phx-submit="clipper:save"
          class="w-1/3 text-white text-xl font-code align-middle"
        >
          <input type="hidden" name={@clip_form[:id].name} value={@clip_form[:id].value} />
          <button 
            class="border border-gray-500 bg-neutral-900 hover:bg-neutral-700"
          >New Clip</button>
        </.form> --%>

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
    dbg(params["token"])

    # dbg(socket.assigns[:live_action])

    socket = assign(socket, 
      client: nil,
      is_connected?: false,
      watcher_form: nil,
      clip_form: nil,
      clips: %{},
      auth_token: params["token"]
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
  def handle_event("setup:start", _params, socket) do
    socket = assign(socket, 
      client: get_supabase_client()
    )
    # {:noreply, socket}
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
        id = DateTime.utc_now(:second) |> to_string()

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
