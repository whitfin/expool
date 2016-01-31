defmodule Expool do
  @moduledoc """
  This module provides a simple interface for concurrent process usage. The
  `Expool.create_pool/2` function is used to create a base pool of processes,
  and is then used for task sumission using `Expool.submit/2`.
  """
  defstruct name: nil, opts: nil, pool: nil, size: nil, active: true

  # alias both Expool.Balancers/Internal/Options
  alias Expool.Balancers, as: Balancers
  alias Expool.Internal, as: Internal
  alias Expool.Options, as: Options

  @doc """
  Creates a new set of N Processes, adding them to a Map so they
  can be referenced at a later time. Processes various options using
  Expool.Options.parse/1, and potentially binds the pool to a name via
  Agent.

  ## Options
    * `:register` - a name to register the pool against (defaults to using `nil`)
    * `:strategy` - the balancing strategy to use (defaults to `:round_robin`)

  """
  @spec create_pool(number, list) :: Expool
  def create_pool(size, opts \\ []) when size > 0 and is_list(opts) do
    gen_args = Keyword.get(opts, :args, fn -> [] end)
    options = Options.parse(opts)

    pool = Enum.reduce(1..size, Map.new(), fn(num, dict) ->
      args = gen_args.()
      unless is_list(args) do
        args = case args do
          nil -> []
          arg -> [arg]
        end
      end
      Map.put(dict, num, Internal.start(args))
    end)

    Agent.start_link(fn -> %{} end, name: :expool_rounds)

    expool = %Expool{
      opts: options,
      pool: pool,
      size: size
    }

    result = case options.register do
      nil ->
        case Agent.start_link(fn -> expool end) do
          { :ok, pid } = output ->
            Agent.update(pid, fn(pool) ->
              %Expool{ pool | name: pid }
            end)
            output
          error -> error
        end
      name ->
        Agent.start_link(fn ->
          %Expool{ expool | name: name }
        end, name: name)
    end

    case result do
      { :ok, pid } -> { :ok, get_pool(pid) }
      { :error, _msg } = err -> err
    end
  end

  @doc """
  Retrieves a registered pool by name or PID. This is a shorthand for calling
  the Agent manually.
  """
  @spec get_pool(atom | pid) :: Expool
  def get_pool(id) when is_atom(id) or is_pid(id) do
    Agent.get(id, &(&1))
  end

  @doc """
  Submits a task to a pool, either provided or by name. Returns error tuples
  if the pool is either inactive or invalid. If valid, a pid will be chosen
  based on the selection methods of the pool, and the task will be forwarded.

  If there is a name registered, the Agent will have the state updated when
  appropriate, to reflect any changes inside the pool.
  """
  @spec submit(Expool | atom | pid, function) :: { atom, pid }
  def submit(%Expool{ name: name } = _pool, action)
  when is_function(action) do
    submit_internal(name, action)
  end
  def submit(id, action)
  when (is_atom(id) or is_pid(id)) and is_function(action) do
    submit_internal(id, action)
  end

  # Internal submission, taking an id or pool, retrieving the pool, and then
  # firing off the task. This is needed to ensure we always keep internal
  # states up to date.
  @spec submit_internal(Expool | atom | pid, function) :: { atom, pid }
  defp submit_internal(%Expool{ active: false }, _) do
    { :error, "Task submitted to inactive pool!" }
  end
  defp submit_internal(id, action)
  when (is_atom(id) or is_pid(id)) and is_function(action) do
    id
    |> get_pool
    |> submit_internal(action)
  end
  defp submit_internal(%Expool{ } = pool, action) when is_function(action) do
    index = Balancers.balance(pool.opts.strategy, pool)
    pid = pool.pool[index]
    send(pid, { :spawn, action })
    { :ok, pid }
  end
  defp submit_internal(_, _) do
    { :error, "Invalid Expool provided on submission!" }
  end

  @doc """
  Terminates all processes inside a pool, either  provided or by name. Returns
  a pool marked as inactive to avoid developers sending uncaught messages through
  the pipeline.
  """
  @spec terminate(Expool | atom | pid) :: Expool
  def terminate(%Expool{ } = pool), do: terminate(pool.name)
  def terminate(id) when is_atom(id) or is_pid(id) do
    Agent.get_and_update(id, fn(pool) ->
      pool.pool
      |> Map.values
      |> Enum.each(&(Process.exit(&1, :shutdown)))

      pool = %Expool{ pool | active: false }

      { { :ok, pool }, pool }
    end)
  end

end
