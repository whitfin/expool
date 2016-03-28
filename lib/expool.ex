defmodule Expool do
  @moduledoc """
  This module provides a simple interface for concurrent process usage. The
  `Expool.create_pool/2` function is used to create a base pool of processes,
  and is then used for task submission using `Expool.submit/2`.
  """

  # alias some stuff
  alias Expool.Balancers
  alias Expool.Internal
  alias Expool.Options

  defstruct active: true,
            balancer: nil,
            opts: nil,
            pool: nil,
            size: nil

  @doc """
  Creates a new set of `size` processes, adding them to a Map so they can be
  referenced at a later time. Parses various options using `Expool.Options.parse/1`,
  and potentially binds the pool to a name via Agent.

  ## Options

    * `:name` - a name to register the pool against (defaults to using `nil`)
    * `:strategy` - the balancing strategy to use (defaults to `:round_robin`)

  """
  @spec create_pool(number, list) :: { atom, Expool }
  def create_pool(size, opts \\ []) when size > 0 and is_list(opts) do
    options =
      opts
      |> Options.parse

    pool =
      1..size
      |> Enum.reduce(%{}, fn(num, dict) ->
          args =
            options.arg_generate.()
            |> List.wrap

          { :ok, worker } =
            args
            |> Internal.start_link

          Map.put(dict, num, worker)
        end)

    base_pool = Balancers.setup(%Expool{
      opts: options,
      pool: pool,
      size: size
    })

    Agent.start_link(fn -> base_pool end, case options.register do
      nil  -> []
      name -> [ name: name ]
    end)
  end

  @doc """
  Retrieves a registered pool by name or PID. This is a shorthand for calling
  the Agent manually, but it will return an error if a valid pool is not found.
  """
  @spec get_pool(atom | pid) :: Expool
  def get_pool(id) when is_atom(id) or is_pid(id) do
    Agent.get(id, fn
      (%Expool{ } = pool) -> { :ok, pool }
      (_other) -> { :error, :not_found }
    end)
  end

  @doc """
  Submits a task to a pool, either provided or by name. Returns error tuples
  if the pool is either inactive or invalid. If valid, a pid will be chosen
  based on the selection methods of the pool, and the task will be forwarded.

  If there is a name registered, the Agent will have the state updated when
  appropriate, to reflect any changes inside the pool.
  """
  @spec submit(Expool | atom | pid, function) :: { atom, pid }
  def submit(%Expool{ active: true } = pool, action) when is_function(action) do
    { index, new_pool } =
      pool
      |> Balancers.balance

    pool.pool
    |> Map.get(index)
    |> Internal.execute(action)
    |> Tuple.append(new_pool)
  end
  def submit(%Expool{ active: false } = _pool, _action) do
    { :error, "Task submitted to inactive pool!" }
  end
  def submit(id, action) when is_atom(id) or is_pid(id) do
    Agent.get_and_update(id, fn(pool) ->
      case submit(pool, action) do
        { :error, _msg } = error ->
          { error, pool }
        { :ok, pid, new_pool } ->
          { { :ok, pid }, new_pool }
      end
    end)
  end

  @doc """
  Terminates all processes inside a pool, either  provided or by name. Returns
  a pool marked as inactive to avoid developers sending uncaught messages through
  the pipeline.
  """
  @spec terminate(Expool | atom | pid) :: Expool
  def terminate(%Expool{ pool: pids } = pool) do
    pids
    |> Map.values
    |> Enum.each(&(Process.exit(&1, :normal)))

    { :ok, %Expool{ pool | active: false } }
  end
  def terminate(id) when is_atom(id) or is_pid(id) do
    Agent.get_and_update(id, fn(pool) ->
      case terminate(pool) do
        { :error, _msg } = error ->
          { error, pool }
        { :ok, new_pool } ->
          { { :ok, true }, new_pool }
      end
    end)
  end

end
