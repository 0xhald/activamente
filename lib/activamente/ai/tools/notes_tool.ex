defmodule Activamente.AI.Tools.NotesTool do
  @moduledoc """
  Tool for creating and managing notes through AI function calling.
  """

  alias Activamente.Notes

  @behaviour Activamente.AI.Tools.ToolBehaviour

  @impl true
  def get_definition do
    %{
      "type" => "function",
      "function" => %{
        "name" => "create_note",
        "description" => "Create a new note with title, content, and optional tags and priority",
        "parameters" => %{
          "type" => "object",
          "properties" => %{
            "title" => %{
              "type" => "string",
              "description" => "The title of the note"
            },
            "content" => %{
              "type" => "string", 
              "description" => "The content/body of the note"
            },
            "tags" => %{
              "type" => "array",
              "items" => %{"type" => "string"},
              "description" => "Optional tags for categorizing the note"
            },
            "priority" => %{
              "type" => "string",
              "enum" => ["low", "normal", "high"],
              "description" => "Priority level of the note (default: normal)"
            }
          },
          "required" => ["title", "content"]
        }
      }
    }
  end

  @impl true
  def execute(args, _context) do
    note_attrs = %{
      title: Map.get(args, "title"),
      content: Map.get(args, "content"),
      tags: Map.get(args, "tags", []),
      priority: Map.get(args, "priority", "normal")
    }

    case Notes.create_note(note_attrs) do
      {:ok, note} ->
        %{
          success: true,
          message: "Note created successfully",
          note_id: note.id,
          title: note.title,
          tags: note.tags,
          priority: note.priority
        }

      {:error, changeset} ->
        errors = 
          changeset.errors
          |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)
          |> Enum.join(", ")

        %{
          success: false,
          error: "Failed to create note: #{errors}"
        }
    end
  end
end