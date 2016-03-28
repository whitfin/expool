defmodule Expool.Balancers do
  # require the Logger
  require Logger

  @moduledoc false
  # Balancer module to define various methods of determining which process to
  # call on the next iteration. We expose a setup and a balance method to allow
  # balancers to set up any arguments they need, and to provide a balancing
  # implementation.

  # alias some deps
  alias Expool.Options

  @doc """
  Accepts a pool to use for balancing and returns a tuple of `{ index, new_pool }`
  where `new_pool` is a modified instance of the pool in case the balancer needs
  to carry out any modifications.
  """
  @spec balance(Expool) :: number
  def balance(%Expool{ size: size, opts: %Options { strategy: :random } } = pool) do
    { :crypto.rand_uniform(1, size), pool }
  end
  def balance(%Expool{ balancer: balancer, size: size, opts: %Options { strategy: :round_robin } } = pool) do
    { index, new_balancer } = Map.get_and_update(balancer, "index", fn
      (index) when index == size + 1 ->
        { 1, 2 }
      (index) ->
        { index, index + 1 }
    end)
    { index, %Expool{ pool | balancer: new_balancer } }
  end
  def balance(pool), do: { 1, pool }

  @doc """
  Sets up a pool based on the strategy being used. An Expool includes a special
  "balancer" key which is essentially an arbitrary key designed for use by any
  balancers. This function should return the modified pool.
  """
  @spec setup(Expool) :: Expool
  def setup(%Expool{ opts: %Options { strategy: :round_robin } } = pool),
  do: %Expool{ pool | balancer: %{ "index" => 1 } }
  def setup(%Expool{ } = pool), do: pool

end
