defmodule LiveClipWeb.StreamLive do
  use LiveClipWeb, :live_view

  require Phoenix.Component

  require Logger

  alias LiveClip.Cache

  alias LiveClipWeb.Endpoint

  @refresh_interval 1_000

  def get_sharable_uri(id) do
    "#{Endpoint.url()}/view/#{id}"
  end

  def button_style(nil), do: "border-neutral-500 hover:bg-neutral-800"
  def button_style(_), do: "border-sky-600 hover:border-neutral-500 hover:bg-neutral-800"

  def icon_style(nil), do: "stroke-neutral-600 hover:stroke-sky-600"
  def icon_style(_), do: "stroke-sky-600"

  def time_label_to_string(i) when is_integer(i) do
    cond do
      i === 0 ->
        "just now"

      i < 60 ->
        "#{i}s ago"

      i  ->
        "#{div(i, 60)}min ago"

      # i < 10 ->
      #   "a few seconds ago"

      # i < 50 ->
      #   "less than a minute ago"

      # i < 119 ->
      #   "a minute ago"

      # i < 3600 ->
      #   "#{div(i, 60)} minutes ago"

      # i ->
      #   "#{div(i, 3600)} hours ago"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col bg-neutral-900 text-white/70 p-3">
      <p class="relative text-center font-bold text-xl">Live Stream Clips</p>
      
      <div :if={@event_ids === []} class="pt-10 h-full flex flex-col items-center justify-center">
        <span class="font-bold text-2xl">No clips available.</span>
      </div>

      <div :if={@event_ids !== []} class="mt-10 flex flex-col gap-4 h-full overflow-y-auto">
        <div :for={id <- @event_ids} 
          class="flex flex-col items-center"
          title={id}
        >
          <p class="text-sm text-center">{time_label_to_string(@time_labels[id]) |> String.capitalize()}</p>
          
          <div class="flex flex-row items-center gap-4 py-4 p-2 border rounded border-neutral-800 hover:border-neutral-600">
            <button
              class={[button_style(@selection[{:qr, id}]), "inline-block p-1 border rounded"]} 
              phx-click={JS.push("event:action", value: %{type: "qr-code", id: id})}
            >
              <div class={[icon_style(@selection[{:qr, id}]), "flex flex-row items-center justify-center gap-2"]}>
                <.lucide_icon name="qr-code" />
                <span class="inline-block align-middle font-bold text-white/70">QR Code</span>
              </div>
            </button>

            <button
              class="inline-block p-1 border rounded border-neutral-500 hover:bg-neutral-800" 
              phx-click={JS.push("event:action", value: %{type: "play", id: id})}
            >
              <div class="flex flex-row items-center justify-center gap-2 stroke-neutral-600 hover:stroke-sky-600">
                <.lucide_icon name="square-play" />
                <span class="inline-block align-middle font-bold text-white/70">Play Video</span>
              </div>
            </button>
              
            <div 
              :if={@selection[{:qr, id}] === true and @clip_links[id] !== nil} 
              class="flex flex-col items-center"
            >
              <a
                class="text-neutral-200 underline" 
                href={@clip_links[id].uri} target="#">{@clip_links[id].uri}</a>
              <img src={@clip_links[id].qr_img_src} alt="QR code" />
            </div>
          </div>

          <%!-- <span>id: {inspect(id)}</span> --%>
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
      clip_links: %{},
      time_labels: %{},
      selection: %{},
      ping_timer: nil
    )
    if connected?(socket) do
      # get the cached event ids.
      timer = :timer.send_interval(@refresh_interval, self(), :refresh_interval)
      socket = assign(socket, ping_timer: timer)

      Endpoint.subscribe("watch:1")
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_info(:refresh_interval, socket) do
    socket = update_time_labels(socket)
    {:noreply, socket}
  end

  @impl true
  def handle_info(%{topic: "watch:1", event: "watcher:update", payload: payload}, socket) do
    case payload do
      %{"changes" => %{} = changes} ->
        %{event_ids: event_ids} = socket.assigns
        socket = assign(socket, event_ids: Map.keys(changes) ++ event_ids)
        
        socket = update_time_labels(socket)

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
    socket = assign(socket, :client, LiveClipWeb.Live.SupabaseComponent.get_supabase_client())
    {:noreply, socket}
  end

  def handle_event("event:action", %{"type" => type, "id" => id}, socket) do
    %{selection: selection} = socket.assigns

    key = case type do
      "qr-code" ->
        {:qr, id}
      "play" ->
        {:play, id}
    end
    state = selection[key]

    case type do
      "qr-code" when state === true ->
        socket = assign(socket, 
          selection: Map.delete(selection, key)
        )
        {:noreply, socket}

      "qr-code" when state === nil ->
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
        
        socket = assign(socket, 
          clip_links: Map.put(links, id, clip),
          selection: Map.put(selection, key, true)
        )
        {:noreply, socket}

      "play" ->
        {:noreply, socket}
    end
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

  defp update_time_labels(socket) do
    %{event_ids: ids, time_labels: labels} = socket.assigns

    now = DateTime.utc_now()

    labels = Enum.reduce(ids, labels, fn id, acc ->
      {:ok, timestamp, 0} = DateTime.from_iso8601(id)
      diff = DateTime.diff(now, timestamp)

      Map.put(acc, id, diff)
    end)

    assign(socket, time_labels: labels)
  end
end
