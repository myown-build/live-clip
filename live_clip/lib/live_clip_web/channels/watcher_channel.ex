defmodule LiveClipWeb.WatcherChannel do
  use LiveClipWeb, :channel

  alias LiveClipWeb.Endpoint
  require Logger

  @impl true
  def join("watch:" <> id, payload, socket) do
    dbg([payload, id])

    if authorized?(payload, socket) do
      # :ok = Endpoint.subscribe("creator:1")

      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_info(%{topic: "creator:" <> _id, event: event, payload: payload}, socket) do
    dbg([event, payload])
    # push(socket, event, payload)
    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    Logger.info("unexpected msg #{inspect(msg)}")
    {:noreply, socket}
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("watcher:update", payload, socket) do
    Logger.debug("receiving message")

    Endpoint.broadcast("watch:1", "watcher:update", payload)
    {:noreply, socket}
  end

  def handle_in("cache", payload, socket) do
    dbg(payload)

    case payload do
      %{"changes" => changes} when is_list(changes) ->
        dbg(changes)
        # update the cached data and broadcast the update to live views.

        Endpoint.broadcast("watch:1", "watcher:update", payload)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end

  end

  def handle_in(event, _payload, socket) do
    dbg("unexpected event: #{inspect(event)}")

    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload, socket) do
    dbg(socket.assigns)

    true
  end
end
