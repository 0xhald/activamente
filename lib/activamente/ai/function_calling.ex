defmodule Activamente.AI.FunctionCalling do
  @moduledoc """
  Function calling system for AI tools and actions.
  """

  alias Activamente.AI.Tools.{NotesTool, SearchTool, WeatherTool}

  require Logger

  @available_tools [
    NotesTool,
    SearchTool,
    WeatherTool
  ]

  def get_available_tools do
    @available_tools
    |> Enum.map(& &1.get_definition())
  end

  def execute_function(tool_call, conversation_id) do
    function_name = tool_call["function"]["name"]
    arguments = tool_call["function"]["arguments"]

    # Parse arguments if they're a JSON string
    parsed_args = case arguments do
      args when is_binary(args) ->
        case Jason.decode(args) do
          {:ok, parsed} -> parsed
          {:error, _} -> %{}
        end
      args when is_map(args) -> args
      _ -> %{}
    end

    Logger.info("Executing function: #{function_name} with args: #{inspect(parsed_args)}")

    case find_tool_by_name(function_name) do
      nil ->
        {:error, "Unknown function: #{function_name}"}

      tool_module ->
        try do
          result = tool_module.execute(parsed_args, %{conversation_id: conversation_id})
          {:ok, result}
        rescue
          error ->
            Logger.error("Function execution error: #{inspect(error)}")
            {:error, "Function execution failed: #{Exception.message(error)}"}
        end
    end
  end

  defp find_tool_by_name(function_name) do
    @available_tools
    |> Enum.find(fn tool ->
      definition = tool.get_definition()
      definition["function"]["name"] == function_name
    end)
  end
end