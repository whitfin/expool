defmodule Expool.Balancers do
  @moduledoc false
  # Balancer module to define various methods of determining which process to
  # call on the next iteration.

  @doc """
  Returns the index of the PID in the pool which should be used when triggering
  another message being sent into the pool. The first argument determines the
  strategy to use, and there are different implementations per strategy. The
  second argument is simply the Expool instance being worked with.
  """
  @spec balance(atom, Expool) :: number
  def balance(:random, %Expool{ size: size } = _pool), do: :random.uniform(size)
  def balance(:round_robin, %Expool{ size: size, name: name } = _pool) do
    Agent.get_and_update(:expool_rounds, fn(rounds) ->
      Map.get_and_update(rounds, name, fn
        (index) when is_number(index) ->
          { index, reset_counter(index, size) }
        (_index) ->
          { 1, reset_counter(1, size) }
      end)
    end)
  end
  def balance(type, _pool) do
    raise ArgumentError, message: "Unrecognised selection method provided: #{type}"
  end

  # Basic shorthand for resetting a counter when max size is hit
  defp reset_counter(index, size) do
    if index == size, do: 1, else: index + 1
  end

end
