defmodule LiveClipWeb.ViewerLive do
  use LiveClipWeb, :live_view

  require Phoenix.Component

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full w-full flex flex-col items-center bg-neutral-900 text-white/70 p-4">
        <.supabase id="supabase-watch" video_id={@video_id}>
          <:viewer>
            <div :if={@video !== nil}>
              <span :if={not @video.exists}>Video does not exist.</span>
              <video :if={@video[:src]} src={@video.src} controls />
            </div>
          </:viewer>
        </.supabase>
        
        <div :if={@video === nil}>
          <span>Loading video...</span>
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
      video_id: video_id,
      video: nil
    )
    if connected?(socket) do
      # subscribe to pubsub events from oz backend.
      # Endpoint.subscribe("watch:1")
      # Endpoint.subscribe("video:#{video_id}")

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
  def handle_event("video:src", params, socket) do
    dbg(params)
    case params do
      %{"exists" => true, "publicUrl" => url} ->
        socket = assign(socket, video: %{exists: true, src: url})
        {:noreply, socket}

      %{} ->
        socket = assign(socket, video: %{exists: false})
        {:noreply, socket}
    end
  end

  def handle_event(event, params, socket) do
    dbg([event, params])
    {:noreply, socket}
  end
end
