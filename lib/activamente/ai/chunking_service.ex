defmodule Activamente.AI.ChunkingService do
  @moduledoc """
  Service for splitting documents into chunks for embedding and retrieval.
  """

  @default_chunk_size 1000
  @default_overlap 200

  def chunk_text(text, opts \\ []) do
    chunk_size = Keyword.get(opts, :chunk_size, @default_chunk_size)
    overlap = Keyword.get(opts, :overlap, @default_overlap)

    text
    |> String.split(~r/\n\s*\n/, trim: true)  # Split by paragraphs
    |> Enum.reduce([], &combine_paragraphs(&1, &2, chunk_size, overlap))
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.map(fn {chunk, index} ->
      %{
        content: String.trim(chunk),
        chunk_index: index,
        metadata: %{
          character_count: String.length(chunk),
          word_count: count_words(chunk)
        }
      }
    end)
  end

  def chunk_csv(csv_content, opts \\ []) do
    chunk_size = Keyword.get(opts, :chunk_size, 10)  # Number of rows per chunk
    
    [header | rows] = String.split(csv_content, "\n", trim: true)
    
    rows
    |> Enum.chunk_every(chunk_size)
    |> Enum.with_index()
    |> Enum.map(fn {chunk_rows, index} ->
      chunk_content = [header | chunk_rows] |> Enum.join("\n")
      
      %{
        content: chunk_content,
        chunk_index: index,
        metadata: %{
          row_count: length(chunk_rows),
          has_header: true,
          csv_chunk: true
        }
      }
    end)
  end

  defp combine_paragraphs(paragraph, acc, chunk_size, overlap) do
    case acc do
      [] ->
        [paragraph]
      
      [current_chunk | rest] ->
        combined = current_chunk <> "\n\n" <> paragraph
        
        if String.length(combined) <= chunk_size do
          [combined | rest]
        else
          # Start new chunk with overlap from previous chunk
          overlap_text = get_overlap_text(current_chunk, overlap)
          new_chunk = if overlap_text != "", do: overlap_text <> "\n\n" <> paragraph, else: paragraph
          [new_chunk, current_chunk | rest]
        end
    end
  end

  defp get_overlap_text(text, overlap_size) do
    if String.length(text) <= overlap_size do
      text
    else
      # Get the last overlap_size characters, but try to break at word boundary
      start_pos = String.length(text) - overlap_size
      overlap_part = String.slice(text, start_pos..-1)
      
      case String.split(overlap_part, " ", parts: 2) do
        [_first_partial_word, rest] -> rest
        [only_word] -> only_word
      end
    end
  end

  defp count_words(text) do
    text
    |> String.split(~r/\s+/, trim: true)
    |> length()
  end
end