defmodule Activamente.AI.RAGPipeline do
  @moduledoc """
  RAG (Retrieval-Augmented Generation) pipeline for answering questions using document context.
  """

  alias Activamente.AI.{LLMClient, EmbeddingService, FunctionCalling}
  alias Activamente.Conversations

  require Logger

  def answer_question(question, conversation_id, opts \\ []) do
    context_limit = Keyword.get(opts, :context_limit, 5)
    provider = Keyword.get(opts, :provider, :openai)
    use_tools = Keyword.get(opts, :use_tools, true)

    # Retrieve relevant context
    context_result = retrieve_context(question, context_limit)

    # Get conversation history
    recent_messages = Conversations.get_recent_messages(conversation_id, 10)

    # Build messages for LLM
    messages = build_messages(question, context_result, recent_messages)

    # Prepare tools if enabled
    tools = if use_tools, do: FunctionCalling.get_available_tools(), else: []

    # Get response from LLM
    case LLMClient.chat_completion(messages, provider: provider, tools: tools) do
      {:ok, response} ->
        # Save user message
        {:ok, _user_msg} =
          Conversations.create_message(%{
            conversation_id: conversation_id,
            role: "user",
            content: question
          })

        # Process function calls if any
        {final_response, function_results} = process_function_calls(response, conversation_id)

        # Save assistant message
        {:ok, assistant_msg} =
          Conversations.create_message(%{
            conversation_id: conversation_id,
            role: "assistant",
            content: final_response["content"],
            function_call: response["tool_calls"],
            function_result: function_results
          })

        {:ok,
         %{
           response: final_response,
           context_used: context_result,
           message_id: assistant_msg.id
         }}

      {:error, reason} ->
        Logger.error("Failed to get LLM response: #{reason}")
        {:error, reason}
    end
  end

  defp retrieve_context(question, limit) do
    case EmbeddingService.search_similar_content(question, limit) do
      {:ok, results} ->
        context_chunks =
          results
          |> Enum.map(fn result ->
            %{
              content: result.content,
              document: result.document.filename,
              similarity: result.similarity
            }
          end)

        {:ok, context_chunks}

      {:error, reason} ->
        Logger.warning("Failed to retrieve context: #{reason}")
        {:ok, []}
    end
  end

  defp build_messages(question, context_result, recent_messages) do
    system_message = build_system_message(context_result)

    # Convert recent messages to LLM format
    history_messages =
      recent_messages
      |> Enum.map(fn msg ->
        %{"role" => msg.role, "content" => msg.content}
      end)

    # Combine system message, history, and current question
    [system_message] ++ history_messages ++ [%{"role" => "user", "content" => question}]
  end

  defp build_system_message({:ok, context_chunks}) when length(context_chunks) > 0 do
    context_text =
      context_chunks
      |> Enum.map_join("\n\n", fn chunk ->
        "From #{chunk.document}:\n#{chunk.content}"
      end)

    %{
      "role" => "system",
      "content" => """
      You are a helpful AI assistant with access to relevant document context and function calling capabilities.

      Context from uploaded documents:
      #{context_text}

      Instructions:
      - Use the provided context to answer questions accurately
      - If the context doesn't contain enough information, say so clearly
      - You can use the available tools to perform actions like saving notes, searching, or getting weather information
      - Be concise but comprehensive in your responses
      - Always cite which documents you're referencing when using context
      """
    }
  end

  defp build_system_message(_) do
    %{
      "role" => "system",
      "content" => """
      You are a helpful AI assistant with function calling capabilities.
      You can use the available tools to perform actions like saving notes, searching, or getting weather information.
      Be concise but comprehensive in your responses.
      """
    }
  end

  defp process_function_calls(response, conversation_id) do
    tool_calls = response["tool_calls"]

    if tool_calls && length(tool_calls) > 0 do
      function_results =
        tool_calls
        |> Enum.map(fn tool_call ->
          case FunctionCalling.execute_function(tool_call, conversation_id) do
            {:ok, result} ->
              %{
                function: tool_call["function"]["name"],
                arguments: tool_call["function"]["arguments"],
                result: result
              }

            {:error, error} ->
              %{
                function: tool_call["function"]["name"],
                arguments: tool_call["function"]["arguments"],
                error: error
              }
          end
        end)

      # If functions were called, make another LLM call with the results
      function_message = %{
        "role" => "assistant",
        "content" => response["content"] || "",
        "tool_calls" => tool_calls
      }

      tool_messages =
        Enum.zip(tool_calls, function_results)
        |> Enum.map(fn {tool_call, result} ->
          %{
            "role" => "tool",
            "tool_call_id" => tool_call["id"],
            "content" => Jason.encode!(result)
          }
        end)

      # Make follow-up call to get final response
      follow_up_messages = [function_message] ++ tool_messages

      case LLMClient.chat_completion(follow_up_messages) do
        {:ok, final_response} ->
          {final_response, function_results}

        {:error, _reason} ->
          # Fallback to original response if follow-up fails
          {response, function_results}
      end
    else
      {response, nil}
    end
  end
end
