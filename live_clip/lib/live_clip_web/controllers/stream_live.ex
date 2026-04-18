defmodule LiveClipWeb.StreamLive do
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-neutral-900 text-white/70 p-4">
      <button 
        :if={@client === nil}
        phx-click={JS.push("setup:start")}
        class="border border-gray-500 bg-neutral-900 hover:bg-neutral-700"
      >Start setup</button>

      <div :if={@client !== nil}>
        <span>Connection to: {@client.url}</span>
        <div 
          id="live-clip-watcher" 
          phx-hook="WatcherHook" 
          phx-change="ignore"
          data-supabase-url={@client.url}
          data-supabase-key={@client.key}
        >
        </div>
      </div>

    </div>
    """
  end

  @impl true
  def mount(params, session, socket) do
    Logger.info("[demo] sesion: #{inspect(session)}, params: #{inspect(params)}")
    hostname = params["hostname"]

    dbg(socket.assigns[:live_action])

    socket = assign(socket, 
      stream_key: nil,
      client: nil
    )

    # socket = load_app(socket, ref)

    if connected?(socket) do
      # subscribe to pubsub events from oz backend.

      # socket = assign(socket, search_form: to_form(%{"query" => ""}))

      # Phoenix.PubSub.subscribe(LiveClip.PubSub, "rtmp:new")

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  # def handle_info({:loader, params}, socket) do
  #   case params do
  #     %{path: path, events: events} ->
  #       socket = assign(socket, events: [path | socket.assigns.events])

  #       {:noreply, socket}

  #     _ ->
  #       {:noreply, socket}
  #   end
  # end

  @impl true
  # def handle_info(%{stream_key: stream_key} = event, socket) do
  #   # handle_webrtc_msg(msg, state)

  #   # dbg(event)

  #   {:noreply, socket}
  # end

  def handle_info(msg, socket) do
    dbg(msg)
    {:noreply, socket}
  end

  @impl true
  def handle_event("setup:start", params, socket) do
    # pass signal along to oz backend to start watching.
    
    dbg(params)
    # %{"query" => query} = params

    socket = assign(socket, :client, @supabase_client)

    # socket = assign(socket, search_form: to_form(%{"query" => query}))
    {:noreply, socket}
  end

  # def handle_event("video:create", params, %{assigns: %{watcher_id: id}} = socket) when id !== nil do
  #   # %{fishmeat_ref: ref} = socket.private
  #   dbg(params)

  #   case Yama.Cache.get({:watcher, id}) do
  #     nil ->
  #       # dbg("bad id #{id}")
  #       {:noreply, socket}

  #     true ->
  #       dbg(socket.assigns.search_form[:query].value)
  #       # value = socket.assigns.search_form[:query].value
  #       # Logger.debug("Creating video #{inspect(id)}")
  #       # Yama.Streamer.create_video(%{id: id, range: {1, 2}})

  #       {:noreply, socket}
  #   end
  # end  


  def handle_event(event, params, socket) do
    dbg([event, params])

    {:noreply, socket}
  end
end
