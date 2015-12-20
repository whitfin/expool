defmodule ExPool do
  @moduledoc """
  The main ExPool interface, allowing for pool creation/termination and
  task submission.
  """
  defstruct index: 1, opts: {}, pool: nil, size: nil, active: true

  @doc """
  Creates a new set of N Processes, adding them to a HashDict so they
  can be referenced at a later time. Processes various options using
  ExPool.Options.parse/1, and potentially binds the pool to a name via
  Agent.
  """
  def create_pool(num, opts \\ []) when is_number(num) and is_list(opts) do
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

    expool = %ExPool{ opts: options, pool: pool, size: num }

    if options.register != nil do
      Agent.start_link(fn -> expool end, [ name: options.register ])
    end

    expool
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
  def submit(%ExPool{ pool: p, size: s, opts: %ExPool.Options { } } = pool, func) when
      is_map(p) and is_number(s) and is_function(func) do

    case pool.opts.selection do
      :round_robin ->
        index = pool.index + 1
        if pool.index == pool.size do
          index = 1
        end
        pool = %ExPool{ pool | index: index }
        if pool.opts.register != nil do
          Agent.update(pool.opts.register, fn(_) -> pool end, 5000)
        end
      :random ->
        index = :random.uniform(pool.size)
      other ->
        raise "Unrecognised selection method provided: #{other}"
    end

    pid = HashDict.get(p, index)

    send(pid, { :spawn, func })

    { :ok, pid, pool }
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
  def terminate(%ExPool{ } = pool) do
    pool.pool
    |> HashDict.values
    |> Enum.each(&(Process.exit(&1, :shutdown)))

    %ExPool{ pool | active: false }
  end
  def terminate(id) when is_atom(id) or is_pid(id) do
    pool = terminate(get_pool(id))
    Agent.update(id, fn(_) -> pool end, 5000)
    pool
  end

end
