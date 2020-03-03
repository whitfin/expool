# Expool
[![Build Status](https://img.shields.io/travis/zackehh/expool.svg)](https://travis-ci.org/zackehh/expool) [![Coverage Status](https://img.shields.io/coveralls/zackehh/expool.svg)](https://coveralls.io/github/zackehh/expool) [![Hex.pm Version](https://img.shields.io/hexpm/v/expool.svg)](https://hex.pm/packages/expool) [![Documentation](https://img.shields.io/badge/docs-latest-yellowgreen.svg)](https://hexdocs.pm/expool/)

A simple Process pooling library to avoid having to repeatedly write the boilerplate into your projects. Supports a couple of cool options, but nothing too crazy (yet). Basically just a way to abstract the spawning of processes and tasks, and ensure you're aware how concurrent your application is (i.e. avoid spawning off millions of procs accidentally).

## Installation

The package can be installed via Hex:

  1. Add expool to your list of dependencies in `mix.exs`:

```elixir
  def deps do
    [{:expool, "~> 0.2.0"}]
  end
```

  2. Ensure expool is started before your application:

```elixir
  def application do
    [applications: [:expool]]
  end
```

## Usage

The general idea is that you create a pool and then submit tasks to it, pretty straightforward stuff:

```elixir
{ :ok, pid } = Expool.create_pool(3) # 3 workers

# `worker_pid` is the Process submitted to, in case you wish
# to send any messages.
{ :ok, worker_pid } = Expool.submit(pid, fn ->
  :timer.sleep(5000)
  IO.puts("Success!")
end)
```

Once you're done with it, you can terminate your pool:

```elixir
{ :ok, pid } = Expool.create_pool(3)
{ :ok, true } = Expool.terminate(pool)
```

Terminating means that all Processes referenced in the pool are killed using `:normal`. This means that sending messages to them will not work (because they're dead). To make this a little nicer, the pool returned by `terminate/1` has an internal flag marking the pool as inactive. This means that you'll receive an error tuple if you try to submit a task to it, allowing you to `case` on the submission.

```elixir
{ :ok, pid } = Expool.create_pool(3)
{ :ok, true } = Expool.terminate(pool)

{ :ok, worker_pid } = Expool.submit(pid, fn ->
  :timer.sleep(5000)
  IO.puts("Success!")
end)

** (MatchError) no match of right hand side value: {:error, "Task submitted to inactive pool!"}
```

## Options

### args

It's sometimes nice to have your Agent supplied with arguments, so that you don't have to care about scoping. Due to this, Expool allows you to specify a list of arguments to be provided to your task scope. You do this by providing an `args` option to `create_pool`. This is either a list or a function (which returns a list). If you wish to pass a single list argument, remember to wrap it up, e.g. `[[head]]` (otherwise you would get `head` as an arg).

It should be noted that an `args` function is executed N times for the number of workers. This sounds stupid (and maybe it is), but the reasoning is that you might wish to open N different database connections. If you want to avoid this, just make your connection outside and then just pass in the list.

```elixir
{ :ok, pid } = Expool.create_pool(3, args: fn ->
  [my_database_client]
end)

{ :ok, worker_pid } = Expool.submit(pid, fn(client) ->
  :timer.sleep(5000)
  IO.puts("Success with a client!")
end)
```

### name

One of the harder things to get used to with Elixir is the scoping; for this reason, you can add a `name` your pool (which literally just uses an `Agent` behind the scenes). This allows you to retrieve your pool from anywhere in your application effortlessly.

```elixir
# setup the pool
{ :ok. pid } = Expool.create_pool(3, name: :mysql_pool)

# somewhere else in your application
{ :ok, pool } = Expool.get_pool(:mysql_pool)

# you can submit to a registered name - this is one of the nicer
# features, because you can blindly use Expool from anywhere
{ :ok, worker_pid } = Expool.submit(:mysql_pool, fn ->
  :timer.sleep(5000)
  IO.puts("Success!")
end)
```

### strategy

By default, Expool uses round-robin strategy methods to pass tasks to the pool. This will just rotate the index used for starting a task, before looping around all potential PIDs.

```elixir
{ :ok, pid } = Expool.create_pool(3, name: :mysql_pool, strategy: :round_robin)

# this will shift the index
{ :ok, worker_pid } = Expool.submit(pid, fn ->
  :timer.sleep(5000)
  IO.puts("Success!")
end)

# the next time you submit using `pid`, the
# next process will receive the task
{ :ok, worker_pid } = Expool.submit(pid, fn ->
  :timer.sleep(5000)
  IO.puts("Success with a client!")
end)
```

The only other currently available selection type is `:random` (which is literally just picking a process at random), but I may add load-based options in future.

## Issues

If you find anything broken in here, please file an issue or a pull request. I wrote this whilst bored on a layover, so it's probably not the best, but it's in use in a couple of projects I'm working with.
