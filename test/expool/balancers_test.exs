defmodule ExpoolBalancersTest do
  use ExUnit.Case
  doctest Expool.Balancers

  test "calling an unrecognised balancer" do
    error = try do
      Expool.Balancers.balance(:fake, Expool.create_pool(3))
    rescue
      e in ArgumentError -> e
    end

    assert(error != nil)
    assert(error.message == "Unrecognised selection method provided: fake")
  end

end
