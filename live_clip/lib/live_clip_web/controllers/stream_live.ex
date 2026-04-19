defmodule LiveClipWeb.StreamLive do
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

  def get_sharable_uri(id) do
    "#{Endpoint.url()}/view/#{id}"
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

      
      <div :if={@event_ids !== []}>
        <div :for={id <- @event_ids} class="p-4 border rounded border-gray-500">
          <span>id: {inspect(id)}</span>

          <button
            :if={@clip_links[id] === nil}
            class="inline-block p-2 border border-gray-500 hover:bg-neutral-800" 
            phx-click={JS.push("event:action", value: %{id: id})}
          >Share with QR</button>
          
          <div :if={@clip_links[id] !== nil} class="p-4 bg-neutral-200 flex flex-col items-center">
            <img src={@clip_links[id].qr_img_src} alt="QR code" />
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def mount(params, session, socket) do
    Logger.info("[demo] sesion: #{inspect(session)}, params: #{inspect(params)}")
    # hostname = params["hostname"]

    dbg(socket.assigns[:live_action])

    socket = assign(socket, 
      client: nil,
      event_ids: [],
      clip_links: %{}
    )
    if connected?(socket) do
      Endpoint.subscribe("watch:1")
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info(%{topic: "watch:1", event: "watcher:update", payload: payload}, socket) do
    case payload do
      %{"changes" => %{} = changes} ->
        %{event_ids: event_ids} = socket.assigns

        socket = assign(socket, event_ids: Map.keys(changes) ++ event_ids)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end

  end

  def handle_info(msg, socket) do
    dbg(msg)
    {:noreply, socket}
  end

  @impl true
  def handle_event("setup:start", params, socket) do
    dbg(params)
    socket = assign(socket, :client, get_supabase_client())
    {:noreply, socket}
  end

  def handle_event("event:action", %{"id" => id}, socket) do
    %{clip_links: links} = socket.assigns

    clip = case Cache.get({:clip, id}) do
      nil ->
        uri = get_sharable_uri(id) 
        clip = generate_clip(uri)
        Cache.put({:clip, id}, clip)
        clip

      %{uri: _} = clip ->
        clip
    end
    
    socket = assign(socket, clip_links: Map.put(links, id, clip))

    {:noreply, socket}
  end

  def handle_event(event, params, socket) do
    dbg([event, params])
    {:noreply, socket}
  end

  defp generate_clip(uri) when is_binary(uri) and byte_size(uri) < 1_000 do
    png_settings = %QRCode.Render.PngSettings{
      background_color: "#ffffff",
      qrcode_color: {0, 0, 0},
      scale: 5
    }
    png_src = 
      uri
      |> QRCode.create()
      |> QRCode.render(:png, png_settings)
      |> QRCode.to_base64()
      |> then(fn {:ok, content} ->
       "data:image/png;base64," <> content
      end)

    %{uri: uri, qr_img_src: png_src}
  end
end
