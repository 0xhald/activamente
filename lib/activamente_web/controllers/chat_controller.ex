defmodule ActivamenteWeb.ChatController do
  use ActivamenteWeb, :controller

  alias Activamente.{Conversations}
  alias Activamente.AI.RAGPipeline

  def create_message(conn, %{"conversation_id" => conversation_id, "message" => message}) do
    case RAGPipeline.answer_question(message, conversation_id) do
      {:ok, %{response: response} = result} ->
        json(conn, %{
          success: true,
          response: response["content"],
          context_used: result[:context_used],
          message_id: result[:message_id]
        })

      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: reason})
    end
  end

  def get_messages(conn, %{"id" => conversation_id}) do
    messages = Conversations.get_conversation_messages(conversation_id)
    
    formatted_messages = 
      messages
      |> Enum.map(fn msg ->
        %{
          id: msg.id,
          role: msg.role,
          content: msg.content,
          inserted_at: msg.inserted_at,
          function_call: msg.function_call,
          function_result: msg.function_result
        }
      end)

    json(conn, %{messages: formatted_messages})
  end
end