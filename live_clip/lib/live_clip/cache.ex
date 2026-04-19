defmodule LiveClip.Cache do
  @moduledoc """
    In-memory storage
  """

  use Task, restart: :permanent

  require Logger

  @default_name __MODULE__
  @ets_opts [
    :named_table,
    :public,
    write_concurrency: true,
    read_concurrency: true
  ]

  # :ets.update_counter(

  def start_link(options \\ []) do
    name = Keyword.get(options, :name, @default_name)
    # on_init = Keyword.get()

    on_init = &myown_init/1

    # parent = self()
    Task.start_link(fn ->
      :ets.new(name, @ets_opts)

      on_init.(name)

      Process.hibernate(Function, :infinity, [])
    end)
  end


  def put(key, value) do
    put(@default_name, key, value)
  end

  def put(table, key, value) do
    :ets.insert(table, {key, value})
  end

  def get(key) do
    get(@default_name, key)
  end

  def get(table, key) do
    # Logger.debug("get #{inspect(key)}")

    case :ets.lookup(table, key) do
      [] -> nil
      [{^key, value}] -> value
    end
  end

  def fetch!(key) do
    fetch!(@default_name, key)
  end

  def fetch!(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> value
    end
  end

  def myown_init(name) do
    Logger.info("Cache init #{inspect(name)}")
    :ok
  end
end
