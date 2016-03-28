defmodule Expool.Options do
  @moduledoc false
  # Option parser for Expool, to normalize the keyword lists into a more
  # recognisable structure. This makes it easier to understand pattern matching
  # on the Options further down the execution path.

  defstruct arg_generate: nil,
            register: nil,
            strategy: nil

  @doc """
  Parses a keyword list to `%Expool.Options{ }` for easier access in future use
  throughout the application. We just take certain keys from the options list and
  default them if they're missing.
  """
  @spec parse([ { atom, atom } ]) :: Expool.Options
  def parse(opts \\ []) do
    %Expool.Options{
      arg_generate: case opts[:args] do
        fun when is_function(fun) ->
          fun
        args when is_list(args) ->
          fn -> args end
        _invalid_function ->
          fn -> [] end
      end,
      register: Keyword.get(opts, :name),
      strategy: Keyword.get(opts, :strategy, :round_robin)
    }
  end

end
