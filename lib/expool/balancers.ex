defmodule ExPool.Balancers do

  def balance(:random, %ExPool{ size: size } = _pool), do: :random.uniform(size)
  def balance(:round_robin, %ExPool{ size: size, name: name } = _pool) do
    rounds = Agent.get(:expool_rounds, &(&1))

    { index, rounds } = Map.get_and_update(rounds, name, fn
      (index) when is_number(index) ->
        { index, (if index == size, do: 1, else: index + 1) }
      (nil) ->
        { 1, (if size == 1, do: 1, else: 2) }
    end)

    Agent.update(:expool_rounds, fn(_) -> rounds end)

    index
  end

  def balance(type, _pool) do
    raise "Unrecognised selection method provided: #{type}"
  end

end
