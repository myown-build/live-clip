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
      client: nil
    )
    if connected?(socket) do
      # subscribe to pubsub events from oz backend.

      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
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

  def handle_event(event, params, socket) do
    dbg([event, params])

    {:noreply, socket}
  end
end
