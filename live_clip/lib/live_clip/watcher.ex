defmodule LiveClip.Watcher do
  alias LiveClip.Cache

  require Logger

  use Slipstream,
    restart: :temporary

  require Logger

  @topic "watch:1"

  def start_or_fetch_watcher!(uri, token) do
    uri = 
      uri
      |> URI.parse()
      |> Map.put(:query, "token=#{token}")
      |> URI.to_string()

    case DynamicSupervisor.start_child(
      LiveClip.DynamicSupervisor, 
      {__MODULE__, %{config: [uri: uri]}}
    ) do
      {:error, {:already_started, pid}} ->
        pid

      {:ok, pid} ->
        pid
    end
  end

  def send_message!(watcher, payload) do
    GenServer.call(watcher, {:push, payload})
  end

  def create_token(user_id) do
    Phoenix.Token.sign(LiveClipWeb.Endpoint, "user auth", 1)
  end

  def start_link(args) do
    Slipstream.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl Slipstream
  def init(%{config: config} = _params) do
    dbg(config)

    Logger.info("connecting #{inspect(config)}")

    {:ok, connect!(config), {:continue, :start_ping}}
  end

  @impl Slipstream
  def handle_continue(:start_ping, socket) do
    timer = :timer.send_interval(10_000, self(), :request_metrics)

    {:noreply, assign(socket, :ping_timer, timer)}
  end

  @impl Slipstream
  def handle_connect(socket) do
    {:ok, join(socket, @topic)}
  end

  @impl Slipstream
  def handle_join(@topic, _join_response, socket) do
    # an asynchronous push with no reply:
    push(socket, @topic, "hello", %{})

    {:ok, socket}
  end

  @impl Slipstream
  def handle_info(:request_metrics, socket) do
    # we will asynchronously receive a reply and handle it in the
    # handle_reply/3 implementation below

    value = Cache.get(:latest)
    {:ok, ref} = push(socket, @topic, "cache", %{latest: value})

    Cache.put(:latest, :erlang.monotonic_time(:millisecond))

    {:noreply, assign(socket, :metrics_request, ref)}
  end

  @impl Slipstream
  def handle_call({:push, message}, _from, socket) do
    {:ok, ref} = Slipstream.push(socket, @topic, "watcher:update", message)

    {:reply, {:ok, ref}, socket}
  end

  @impl Slipstream
  def handle_reply(ref, metrics, socket) do
    if ref == socket.assigns.metrics_request do
      dbg(metrics)
      # :ok = MyApp.MetricsPublisher.publish(metrics)
    end

    {:ok, socket}
  end

  @impl Slipstream
  def handle_message(@topic, "watcher:update", message, socket) do
    dbg(message)

    {:ok, socket}
  end

  def handle_message(@topic, event, message, socket) do
    Logger.error(
      "Was not expecting a push from the server. Heard: " <>
        inspect({@topic, event, message})
    )

    {:ok, socket}
  end

  @impl Slipstream
  def handle_disconnect(_reason, socket) do
    :timer.cancel(socket.assigns.ping_timer)

    {:stop, :normal, socket}
  end


  def create_clip(channel) do
    # SocketClient.Channel.push(channel, "new_msg", %{"body" => "Hello"})
  end



  # @impl true
  # def handle_call({:create_video, %{id: _} = params}, _from, state) do
  #   Logger.debug("creating video #{inspect(params)}")

  #   %{id: id, range: range} = params
  #   opts = [source_id: id, range: range]

  #   # {:ok, _, pipeline} = Membrane.Pipeline.start_link(Pipeline.SourceToFile, opts)

  #   state = put_in(state.videos[id], pipeline)
  #   {:reply, pipeline, state}
  # end

  # def handle_call({:create, %{client_ref: client_ref}}, _from, state) do
  #   # Logger.debug("starting pipeline")
  #   {:ok, _supervisor, pipeline} = Membrane.Pipeline.start_link(Pipeline, client_ref: client_ref)

  #   state = Map.put(state, client_ref, pipeline)
  #   {:reply, pipeline, state}
  # end

end