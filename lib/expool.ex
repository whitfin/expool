defmodule ExPool do
  @moduledoc """
  The main ExPool interface, allowing for pool creation/termination and
  task submission.
  """
  defstruct name: nil, opts: nil, pool: nil, size: nil, active: true

  @doc """
  Creates a new set of N Processes, adding them to a HashDict so they
  can be referenced at a later time. Processes various options using
  ExPool.Options.parse/1, and potentially binds the pool to a name via
  Agent.
  """
  def create_pool(num, opts \\ []) when num > 0 and is_list(opts) do
    gen_args = Keyword.get(opts, :args, fn -> [] end)
    options = ExPool.Options.parse(opts)

    pool = Enum.reduce(1..num, HashDict.new(), fn(num, dict) ->
      args = gen_args.()
      unless is_list(args) do
        args = case args do
          nil -> []
          arg -> [arg]
        end
      end
      HashDict.put(dict, num, ExPool.Internal.start(args))
    end)

    expool = %ExPool{
      opts: options,
      pool: pool,
      size: num
    }

    Agent.start_link(fn -> %{} end, name: :expool_rounds)

    result = case options.register do
      nil ->
        case Agent.start_link(fn -> expool end) do
          { :ok, pid } = output ->
            Agent.update(pid, fn(pool) -> %ExPool{ pool | name: pid } end)
            output
          error -> error
        end
      name ->
        Agent.start_link(fn ->
          %ExPool{ expool | name: name }
        end, name: name)
    end

    case result do
      { :ok, pid } -> { :ok, get_pool(pid) }
      { :error, _msg } = err -> err
    end
  end

  @doc """
  Retrieves a registered pool by name. If none is found, Agent will raise
  an error, so we don't have to care explicitly.
  """
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
  def submit(%ExPool{ active: false }, _) do
    { :error, "Task submitted to inactive pool!" }
  end
  def submit(%ExPool{ pool: p, size: s } = pool, func)
  when is_map(p) and is_number(s) and is_function(func) do

    index = ExPool.Balancers.balance(pool.opts.balancer, pool)
    pid = HashDict.get(p, index)
    send(pid, { :spawn, func })

    { :ok, pid }
  end
  def submit(id, func) when (is_atom(id) or is_pid(id)) and is_function(func) do
    submit(get_pool(id), func)
  end
  def submit(_, _) do
    { :error, "Invalid ExPool provided on submission!" }
  end

  @doc """
  Terminates all processes inside a pool, either  provided or by name. Returns
  a pool marked as inactive to avoid developers sending uncaught messages through
  the pipeline.
  """
  def terminate(%ExPool{ } = pool), do: terminate(pool.name)
  def terminate(id) when is_atom(id) or is_pid(id) do
    pool = get_pool(id)

    pool.pool
    |> HashDict.values
    |> Enum.each(&(Process.exit(&1, :shutdown)))

    pool = %ExPool{ pool | active: false }

    Agent.update(id, fn(_) -> pool end, 5000)

    pool
  end

end
