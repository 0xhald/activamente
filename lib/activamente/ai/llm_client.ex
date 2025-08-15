defmodule Activamente.AI.LLMClient do
  @moduledoc """
  Client for interacting with LLM APIs (OpenAI, Anthropic).
  """

  require Logger

  @config Application.get_env(:activamente, :ai, [])

  def chat_completion(messages, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)
    model = Keyword.get(opts, :model, @config[:chat_model] || "gpt-4o-mini")
    max_tokens = Keyword.get(opts, :max_tokens, @config[:max_tokens] || 4096)
    temperature = Keyword.get(opts, :temperature, @config[:temperature] || 0.7)
    tools = Keyword.get(opts, :tools, [])

    case provider do
      :openai -> openai_chat_completion(messages, model, max_tokens, temperature, tools)
      _ -> {:error, "Unsupported provider"}
    end
  end

  def generate_embedding(text, opts \\ []) do
    model = Keyword.get(opts, :model, @config[:embedding_model] || "text-embedding-3-small")
    openai_embedding(text, model)
  end

  defp openai_chat_completion(messages, model, max_tokens, temperature, tools) do
    api_key = @config[:openai_api_key]

    if is_nil(api_key) do
      {:error, "OpenAI API key not configured"}
    else
      headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"}
      ]

      body = %{
        model: model,
        messages: messages,
        max_tokens: max_tokens,
        temperature: temperature
      }

      body = if tools != [], do: Map.put(body, :tools, tools), else: body

      case Req.post("https://api.openai.com/v1/chat/completions",
             headers: headers,
             json: body
           ) do
        {:ok, %{status: 200, body: response}} ->
          choice = List.first(response["choices"])
          {:ok, choice["message"]}

        {:ok, %{status: status, body: body}} ->
          Logger.error("OpenAI API error: #{status} - #{inspect(body)}")
          {:error, "API request failed: #{status}"}

        {:error, reason} ->
          Logger.error("OpenAI API request failed: #{inspect(reason)}")
          {:error, "Request failed: #{reason}"}
      end
    end
  end

  defp openai_embedding(text, model) do
    api_key = @config[:openai_api_key]

    if is_nil(api_key) do
      {:error, "OpenAI API key not configured"}
    else
      headers = [
        {"Authorization", "Bearer #{api_key}"},
        {"Content-Type", "application/json"}
      ]

      body = %{
        model: model,
        input: text,
        encoding_format: "float"
      }

      case Req.post("https://api.openai.com/v1/embeddings",
             headers: headers,
             json: body
           ) do
        {:ok, %{status: 200, body: response}} ->
          embedding = get_in(response, ["data", Access.at(0), "embedding"])
          {:ok, embedding}

        {:ok, %{status: status, body: body}} ->
          Logger.error("OpenAI Embeddings API error: #{status} - #{inspect(body)}")
          {:error, "API request failed: #{status}"}

        {:error, reason} ->
          Logger.error("OpenAI Embeddings API request failed: #{inspect(reason)}")
          {:error, "Request failed: #{reason}"}
      end
    end
  end
end
