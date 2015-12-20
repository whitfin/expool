defmodule ExPool.Options do
  @moduledoc """
  Option parser for ExPool, to normalize the keyword lists into
  a more recognisable structure.
  """
  defstruct register: nil, selection: nil

  @doc """
  Parses a keyword list to %ExPool.Options{ } for easier access
  in future use throughout the application.
  """
  def parse(opts \\ []) do
    %ExPool.Options {
      register:   Keyword.get(opts, :register, nil),
      selection:  Keyword.get(opts, :selection, :round_robin)
    }
  end

end
