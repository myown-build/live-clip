defmodule LiveClipWeb.AuthLive do
  use LiveClipWeb, :live_view

  require Phoenix.Component

  require Logger

  # alias LiveClipWeb.Endpoint

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col gap-3 bg-neutral-900 text-white/70 p-4">
      <div class="w-full flex flex-col items-center bg-neutral-700 p-4 border rounded border-gray-500">
        <span class="text-lg select-none">Sign-in using Supabase Auth</span>
        <.supabase id="supabase-watch">
          <:auth_otp :let={form}>
            <div class="w-80 bg-neutral-400 p-3 text-white flex flex-col items-center">
              <.input class="w-full" field={form[:email]} label="Email" />

              <button 
                :if={form[:email].value not in [nil, ""]}
                class="mt-2 border p-2 rounded border-gray-500 bg-neutral-900 hover:bg-neutral-700"
                >Send sign-in link</button>
            </div>
          </:auth_otp>
        </.supabase>
      </div>
    </div>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      {:ok, socket}
    else
      {:ok, socket}
    end
  end

  @impl true
  def handle_event(event, params, socket) do
    dbg({event, params})

    {:noreply, socket}
  end
end
