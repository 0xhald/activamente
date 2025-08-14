defmodule ActivamenteWeb.NotesController do
  use ActivamenteWeb, :controller

  alias Activamente.Notes

  def index(conn, params) do
    notes = case Map.get(params, "status") do
      nil -> Notes.list_notes()
      status -> Notes.list_notes_by_status(status)
    end

    formatted_notes = 
      notes
      |> Enum.map(fn note ->
        %{
          id: note.id,
          title: note.title,
          content: note.content,
          tags: note.tags,
          priority: note.priority,
          status: note.status,
          inserted_at: note.inserted_at,
          updated_at: note.updated_at
        }
      end)

    json(conn, %{notes: formatted_notes})
  end

  def create(conn, %{"note" => note_params}) do
    case Notes.create_note(note_params) do
      {:ok, note} ->
        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          note: %{
            id: note.id,
            title: note.title,
            content: note.content,
            tags: note.tags,
            priority: note.priority,
            status: note.status,
            inserted_at: note.inserted_at
          }
        })

      {:error, changeset} ->
        errors = 
          changeset.errors
          |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Note creation failed", details: errors})
    end
  end
end