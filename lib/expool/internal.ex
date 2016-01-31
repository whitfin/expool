defmodule Expool.Internal do
  @moduledoc false
  # Internal infinite server, being used as the main driver behind
  # each worker inside the Process pools.

  @doc """
  Simply spawns off a new Process with the provided arguments.
  """
  def start(args) when is_list(args) do
    spawn(fn -> listen(args) end)
  end

  # Recursively calls itself keeping the args in scope. When a message
  # is received, assuming it's a spawn/function combination, the function
  # is executed with the arguments passed in. As a fallback, an error is
  # logged if the message is unrecognised.
  defp listen(args) do
    receive do
      { :spawn, action } when is_function(action) ->
        apply(action, args)
      message -> IO.puts("Unrecognised message: #{inspect message}")
    end
    listen(args)
  end

end
