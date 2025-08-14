defmodule Activamente.AI.Tools.ToolBehaviour do
  @moduledoc """
  Behaviour for AI function calling tools.
  """

  @callback get_definition() :: map()
  @callback execute(args :: map(), context :: map()) :: map()
end