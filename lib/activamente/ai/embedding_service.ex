defmodule Activamente.AI.EmbeddingService do
  @moduledoc """
  Service for generating and storing embeddings for document chunks.
  """

  alias Activamente.AI.LLMClient
  alias Activamente.Documents

  require Logger

  def generate_embeddings_for_document(document_id) do
    case Documents.get_document(document_id) do
      nil ->
        {:error, :document_not_found}

      _document ->
        chunks = Documents.get_chunks_for_document(document_id)
        
        results = 
          chunks
          |> Enum.map(&generate_embedding_for_chunk/1)
          |> Enum.reduce({[], []}, fn
            {:ok, chunk}, {successful, errors} -> {[chunk | successful], errors}
            {:error, error}, {successful, errors} -> {successful, [error | errors]}
          end)

        case results do
          {successful_chunks, []} ->
            Logger.info("Successfully generated embeddings for #{length(successful_chunks)} chunks")
            Documents.mark_document_processed(document_id, length(successful_chunks))
            {:ok, successful_chunks}

          {successful_chunks, errors} ->
            Logger.error("Generated embeddings for #{length(successful_chunks)} chunks, #{length(errors)} failed")
            {:partial_success, successful_chunks, errors}
        end
    end
  end

  def generate_embedding_for_chunk(chunk) do
    case LLMClient.generate_embedding(chunk.content) do
      {:ok, embedding} ->
        case Documents.update_chunk(chunk, %{embedding: embedding}) do
          {:ok, updated_chunk} ->
            {:ok, updated_chunk}

          {:error, changeset} ->
            Logger.error("Failed to update chunk with embedding: #{inspect(changeset.errors)}")
            {:error, :update_failed}
        end

      {:error, reason} ->
        Logger.error("Failed to generate embedding for chunk #{chunk.id}: #{reason}")
        {:error, reason}
    end
  end

  def search_similar_content(query, limit \\ 5) do
    case LLMClient.generate_embedding(query) do
      {:ok, query_embedding} ->
        similar_chunks = Documents.search_similar_chunks(query_embedding, limit)
        
        results = 
          similar_chunks
          |> Enum.map(fn chunk ->
            %{
              chunk: chunk,
              content: chunk.content,
              document: chunk.document,
              similarity: calculate_similarity(query_embedding, chunk.embedding)
            }
          end)

        {:ok, results}

      {:error, reason} ->
        Logger.error("Failed to generate embedding for search query: #{reason}")
        {:error, reason}
    end
  end

  defp calculate_similarity(embedding1, embedding2) when is_list(embedding1) and is_list(embedding2) do
    # Calculate cosine similarity
    dot_product = 
      embedding1
      |> Enum.zip(embedding2)
      |> Enum.map(fn {a, b} -> a * b end)
      |> Enum.sum()

    magnitude1 = :math.sqrt(Enum.map(embedding1, &(&1 * &1)) |> Enum.sum())
    magnitude2 = :math.sqrt(Enum.map(embedding2, &(&1 * &1)) |> Enum.sum())

    if magnitude1 > 0 and magnitude2 > 0 do
      dot_product / (magnitude1 * magnitude2)
    else
      0.0
    end
  end

  defp calculate_similarity(_embedding1, _embedding2), do: 0.0
end