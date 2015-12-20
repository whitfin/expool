# ExPool [![Build Status](https://travis-ci.org/zackehh/expool.svg?branch=master)](https://travis-ci.org/zackehh/expool) 

A simple Process pooling library to avoid having to repeatedly write the boilerplate into your projects. Supports a couple of cool options, but nothing too crazy (yet).

## Installation

The package can be installed via Hex:

  1. Add expool to your list of dependencies in `mix.exs`:

        def deps do
          [{:expool, "~> 0.0.1"}]
        end

  2. Ensure expool is started before your application:

        def application do
          [applications: [:expool]]
        end

## Usage

The general idea is that you create a pool and then submit tasks to it, pretty straightforward stuff:

```elixir
pool = ExPool.create_pool(3) # 3 workers

# `pid` is the Process submitted to, in case you wish
# to send any messages. Always rebind `pool`.
{ :ok, pid, pool } = ExPool.submit(pool, fn ->
  :timer.sleep(5000)
  IO.puts("Success!")
end)
```

Once you're done with it, you can terminate your pool:

```elixir
pool = ExPool.create_pool(3)
pool = ExPool.terminate(pool)
```

Terminating means that all Processes referenced in the pool are killed using `:shutdown`. This means that sending messages to them will not work (because they're dead). To make this a little nicer, the pool returned by `terminate/1` has an internal flag marking the pool as inactive. This means that you'll receive an error tuple if you try to submit a task to it, allowing you to `case` on the submission.

```elixir
pool = ExPool.create_pool(3)
pool = ExPool.terminate(pool)

{ :ok, pid, pool } = ExPool.submit(pool, fn ->
  :timer.sleep(5000)
  IO.puts("Success!")
end)

** (MatchError) no match of right hand side value: {:error, "Task submitted to inactive pool!"}
```

## Options

### args

It's sometimes nice to have your Agent supplied with arguments, so that you don't have to care about scoping. Due to this, ExPool allows you to specify a list of arguments to be provided to your task scope. You do this by providing an `args` option to `create_pool`, and return a list of the arguments you want to bind. If you wish to pass a single list argument, remember to wrap it up, e.g. `[[head]]` (otherwise you would get `head` as an arg).

It should be noted that your `args` function is executed N times for the number of workers. This sounds stupid (and maybe it is), but the reasoning is that you might wish to open N different database connections (my Elixir isn't good here; does the memory copying between Processes mean that you would share connection otherwise?). If you want to avoid this, just make your connection outside, then make the `args` function return it.

```elixir
pool = ExPool.create_pool(3, args: fn ->
  [my_database_client]
end)

{ :ok, pid, pool } = ExPool.submit(pool, fn(client) ->
  :timer.sleep(5000)
  IO.puts("Success with a client!")
end)
```

### register

One of the harder things to get used to with Elixir is the scoping; for this reason, you can `register` your pool in a namespace (which literally just uses an `Agent` behind the scenes). This allows you to retrieve your pool from anywhere in your application effortlessly.

```elixir
# setup the pool
pool = ExPool.create_pool(3, register: :mysql_pool)

# somewhere else in your application
pool = ExPool.get_pool(:mysql_pool)

# you can submit to a registered name - this is one of the nicer
# features, because you can blindly use ExPool from anywhere
{ :ok, pid, pool } = ExPool.submit(:mysql_pool, fn ->
  :timer.sleep(5000)
  IO.puts("Success with a client!")
end)
```

### selection

By default, ExPool uses round-robin selection methods to pass tasks to the pool **but this only works if you update your pool reference**. Because this is written using an internal counter, passing an older version of the pool will just give to the same Process. This is a pretty poor implementation, but it's sufficient for now as long as you keep it in mind. Also note that if you've registered the pool using `register`, the registered pool also has its index updated in sync.

```elixir
pool = ExPool.create_pool(3, register: :mysql_pool, selection: :round_robin)

# rebinding pool will shift the index
{ :ok, pid, pool } = ExPool.submit(pool, fn ->
  :timer.sleep(5000)
  IO.puts("Success with a client!")
end)

# the next time you submit using `pool`, the
# same process will receive the task
{ :ok, pid, _ } = ExPool.submit(pool, fn(client) ->
  :timer.sleep(5000)
  IO.puts("Success with a client!")
end)

# using a name means that it's always synced for
# you automatically, how convenient
{ :ok, pid, pool } = ExPool.submit(:mysql_pool, fn ->
  :timer.sleep(5000)
  IO.puts("Success with a client!")
end)
```

The only other currently available selection type is `:random`, but I may add load-based options in future.

## Issues

If you find anything broken in here, please file an issue or a pull request. I wrote this whilst bored on a layover, so it's probably not the best.
