defmodule ExpoolTest do
  use ExUnit.Case, async: true

  test "basic pool assigns processes" do
    { :ok, pool } = Expool.create_pool(5)

    assert(pool.active == true)
    assert(pool.opts.register == nil)
    assert(pool.opts.strategy == :round_robin)
    assert(Enum.count(pool.pool) == 5)
    assert(pool.size == 5)
  end

  test "pool can be named" do
    { :ok, pool } = Expool.create_pool(5, name: :test)

    assert(pool.active == true)
    assert(pool.name == :test)
    assert(pool.opts.register == :test)
    assert(pool.opts.strategy == :round_robin)
    assert(Enum.count(pool.pool) == 5)
    assert(pool.size == 5)
  end

  test "pool can use random strategy" do
    { :ok, pool } = Expool.create_pool(5, strategy: :random)

    assert(pool.active == true)
    assert(pool.opts.register == nil)
    assert(pool.opts.strategy == :random)
    assert(Enum.count(pool.pool) == 5)
    assert(pool.size == 5)
  end

  test "pool can have an argument bound" do
    { :ok, pool } = Expool.create_pool(5, args: fn -> 1 end)
    { :ok, pid0 } = Agent.start_link(fn -> 0 end)

    Expool.submit(pool, fn(a) ->
      Agent.update(pid0, &(&1 + a))
    end)

    :timer.sleep(1)

    assert(Agent.get(pid0, &(&1)) == 1)
  end

  test "pool can have many arguments bound" do
    { :ok, pool } = Expool.create_pool(5, args: fn -> [1,2,3] end)
    { :ok, pid0 } = Agent.start_link(fn -> 0 end)

    Expool.submit(pool, fn(a, b, c) ->
      Agent.update(pid0, &(&1 + a + b + c))
    end)

    :timer.sleep(1)

    assert(Agent.get(pid0, &(&1)) == 6)
  end

  test "submitting a task to an unnamed pool" do
    { :ok, pool } = Expool.create_pool(3, strategy: :random)
    { :ok, pid0 } = Agent.start_link(fn -> 0 end)

    { :ok, _pid1 } = Expool.submit(pool, fn ->
      Agent.update(pid0, &(&1 + 1))
    end)
    { :ok, _pid2 } = Expool.submit(pool, fn ->
      Agent.update(pid0, &(&1 + 1))
    end)
    { :ok, _pid3 } = Expool.submit(pool, fn ->
      Agent.update(pid0, &(&1 + 1))
    end)
    { :ok, _pid4 } = Expool.submit(pool, fn ->
      Agent.update(pid0, &(&1 + 1))
    end)

    :timer.sleep(1)

    assert(Agent.get(pid0, &(&1)) == 4)
  end

  test "submitting a task to a named pool" do
    { :ok, _pool } = Expool.create_pool(3, name: :test_pool)
    { :ok, pid0 } = Agent.start_link(fn -> 0 end)

    { :ok, pid1 } = Expool.submit(:test_pool, fn ->
      Agent.update(pid0, &(&1 + 1))
    end)
    { :ok, pid2 } = Expool.submit(:test_pool, fn ->
      Agent.update(pid0, &(&1 + 1))
    end)
    { :ok, pid3 } = Expool.submit(:test_pool, fn ->
      Agent.update(pid0, &(&1 + 1))
    end)
    { :ok, pid4 } = Expool.submit(:test_pool, fn ->
      Agent.update(pid0, &(&1 + 1))
    end)

    :timer.sleep(1)

    assert(Agent.get(pid0, &(&1)) == 4)
    assert(pid1 < pid2)
    assert(pid2 < pid3)
    assert(pid3 > pid4)
    assert(pid1 == pid4)
  end

  test "terminating an unnamed pool of processes" do
    { :ok, pool } = Expool.create_pool(3)
    { :ok, new_pool } = Expool.terminate(pool)

    { atom, msg } = Expool.submit(pool, fn -> 1 end)

    assert(new_pool.active == false)
    assert(atom == :error)
    assert(msg == "Task submitted to inactive pool!")
  end

  test "terminating a named pool of processes" do
    { :ok, _pool } = Expool.create_pool(3, name: :my_pool)
    { :ok, new_pool } = Expool.terminate(:my_pool)

    { atom, msg} = Expool.submit(:my_pool, fn -> 1 end)

    assert(new_pool.active == false)
    assert(atom == :error)
    assert(msg == "Task submitted to inactive pool!")
  end

  test "causing an error within the Agent API" do
    { :ok, _pid0 } = Agent.start_link(fn -> 0 end, name: :test_pool)
    { atom, message } = Expool.create_pool(3, name: :test_pool)

    assert(atom == :error)
    assert({ :already_started, _pid } = message)
  end

end
