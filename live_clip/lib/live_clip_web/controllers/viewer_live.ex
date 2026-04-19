defmodule LiveClipWeb.ViewerLive do
  use LiveClipWeb, :live_view

  require Phoenix.Component

  require Logger

  alias LiveClip.Cache

  alias LiveClipWeb.Endpoint

  def get_supabase_client() do
    %{
      url: Application.get_env(:live_clip, :supabase_url),
      key: Application.get_env(:live_clip, :supabase_key)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full w-full flex flex-col items-center bg-neutral-900 text-white/70 p-4">
      <div :if={@client !== nil}>
        <span>Connection to: {@client.url}</span>
        <div 
          id="live-clip-watcher" 
          phx-hook="WatcherHook" 
          phx-change="ignore"
          data-supabase-url={@client.url}
          data-supabase-key={@client.key}
          data-video-id={@video_id}
        >
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(params, session, socket) do
    Logger.info("[demo] sesion: #{inspect(session)}, params: #{inspect(params)}")
    # hostname = params["hostname"]

    video_id = params["id"]

    dbg(socket.assigns[:live_action])

    socket = assign(socket, 
      client: nil,
      event_ids: [],
      clip_links: %{},
      video_id: "example10"
    )
    if connected?(socket) do
      # subscribe to pubsub events from oz backend.
      # Endpoint.subscribe("watch:1")
      # Endpoint.subscribe("video:#{video_id}")
      socket = assign(socket, client: get_supabase_client())

      {:ok, socket, layout: false}
    else
      {:ok, socket, layout: false}
    end
  end

  @impl true
  def handle_info(%{topic: "video" <> _, event: "update", payload: payload}, socket) do
    dbg({:watcher_update, payload})

    # socket = push_event(socket, "viewer:update", %{id: })

    # case socket.assigns do
    #   %{event_ids: event_ids} when is_list(event_ids) ->
    #     socket = assign(socket, event_ids: [1 | event_ids])
    # end
    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    dbg(msg)
    {:noreply, socket}
  end

  @impl true
  # def handle_event("viewer:poll", params, socket) do
  #   dbg(params)
  #   socket = assign(socket, :client, get_supabase_client())
  #   {:noreply, socket}
  # end

  def handle_event(event, params, socket) do
    dbg([event, params])
    {:noreply, socket}
  end
end
