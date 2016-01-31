defmodule Expool.Options do
  @moduledoc false
  # Option parser for Expool, to normalize the keyword lists into
  # a more recognisable structure.
  defstruct register: nil, strategy: nil

  @doc """
  Parses a keyword list to %Expool.Options{ } for easier access
  in future use throughout the application.
  """
  def parse(opts \\ []) do
    %Expool.Options {
      register:  Keyword.get(opts, :name, nil),
      strategy:  Keyword.get(opts, :strategy, :round_robin)
    }
  end

end
