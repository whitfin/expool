defmodule ExpoolBalancersTest do
  use PowerAssert
  doctest Expool.Balancers

  test "calling an unrecognised balancer" do
    { :ok, pid } = Expool.create_pool(3, strategy: :fail)

    pool = Agent.get(pid, &(&1))
    res = Expool.Balancers.balance(pool)

    assert(res == { 1, pool })
  end

end
