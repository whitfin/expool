defmodule Expool.Internal do
  # inherit GenServer
  use GenServer

  @moduledoc false
  # Internal server implementation, being used as the main driver behind each
  # worker in the pool. The server simply has a cast listener accepting a message
  # including the function to execute.

  @doc """
  Starts up a server using the built-in GenServer module. We pass through any
  arguments in order to allow custom arguments in executed functions.
  """
  def start_link(options \\ [], server_opts \\ []) do
    GenServer.start_link(__MODULE__, options, server_opts)
  end

  @doc """
  The main handler, accepting a `:spawn` message alongside an action. The state
  at this point is simply a list of actions to provide to the action to execute.
  """
  def handle_cast({ :spawn, action }, args) when is_function(action) do
    apply(action, args)
    { :noreply, args }
  end

  @doc """
  Simply a catch-all cast to avoid the Server crashing unexpectedly.
  """
  def handle_cast(_, args) do
    { :noreply, args }
  end

  @doc """
  A public function which acts as sugar for the Server calls. This function just
  forwards a message to the backing Server implementation and returns the pid used
  to execute.
  """
  def execute(pid, action) when is_pid(pid) and is_function(action) do
    GenServer.cast(pid, { :spawn, action })
    { :ok, pid }
  end

end
