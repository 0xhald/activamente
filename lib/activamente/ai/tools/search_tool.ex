defmodule Activamente.AI.Tools.SearchTool do
  @moduledoc """
  Tool for searching through documents and notes.
  """

  alias Activamente.Notes
  alias Activamente.AI.EmbeddingService

  @behaviour Activamente.AI.Tools.ToolBehaviour

  @impl true
  def get_definition do
    %{
      "type" => "function",
      "function" => %{
        "name" => "search_knowledge_base",
        "description" => "Search through uploaded documents and notes for relevant information",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "query" => %{
              "type" => "string",
              "description" => "The search query to find relevant content"
            },
            "search_type" => %{
              "type" => "string",
              "enum" => ["documents", "notes", "both"],
              "description" => "What to search: documents, notes, or both (default: both)"
            },
            "limit" => %{
              "type" => "integer",
              "minimum" => 1,
              "maximum" => 20,
              "description" => "Maximum number of results to return (default: 5)"
            }
          },
          "required" => ["query"]
        }
      }
    }
  end

  @impl true
  def execute(args, _context) do
    query = Map.get(args, "query")
    search_type = Map.get(args, "search_type", "both")
    limit = Map.get(args, "limit", 5)

    results = %{}

    # Search documents using vector similarity
    results =
      if search_type in ["documents", "both"] do
        case EmbeddingService.search_similar_content(query, limit) do
          {:ok, document_results} ->
            formatted_docs =
              document_results
              |> Enum.map(fn result ->
                %{
                  type: "document",
                  title: result.document.filename,
                  content: String.slice(result.content, 0, 300) <> "...",
                  similarity: Float.round(result.similarity, 3)
                }
              end)

            Map.put(results, :documents, formatted_docs)

          {:error, _reason} ->
            Map.put(results, :documents, [])
        end
      else
        results
      end

    # Search notes using text search
    results =
      if search_type in ["notes", "both"] do
        notes_results =
          Notes.search_notes(query)
          |> Enum.take(limit)
          |> Enum.map(fn note ->
            %{
              type: "note",
              title: note.title,
              content: String.slice(note.content, 0, 300) <> "...",
              tags: note.tags,
              priority: note.priority,
              status: note.status
            }
          end)

        Map.put(results, :notes, notes_results)
      else
        results
      end

    # Combine and format results
    all_results = []

    all_results =
      if Map.has_key?(results, :documents),
        do: all_results ++ Map.get(results, :documents),
        else: all_results

    all_results =
      if Map.has_key?(results, :notes),
        do: all_results ++ Map.get(results, :notes),
        else: all_results

    %{
      success: true,
      query: query,
      total_results: length(all_results),
      results: all_results,
      summary: generate_search_summary(all_results, query)
    }
  end

  defp generate_search_summary(results, query) do
    count = length(results)
    doc_count = Enum.count(results, &(&1[:type] == "document"))
    note_count = Enum.count(results, &(&1[:type] == "note"))

    cond do
      count == 0 ->
        "No results found for '#{query}'"

      doc_count > 0 and note_count > 0 ->
        "Found #{count} results for '#{query}': #{doc_count} from documents, #{note_count} from notes"

      doc_count > 0 ->
        "Found #{doc_count} document results for '#{query}'"

      note_count > 0 ->
        "Found #{note_count} note results for '#{query}'"
    end
  end
end
