defmodule Activamente.Notes do
  @moduledoc """
  Context for managing notes.
  """

  import Ecto.Query, warn: false
  alias Activamente.Repo
  alias Activamente.Notes.Note

  def list_notes do
    Repo.all(Note)
  end

  def list_notes_by_status(status) do
    from(n in Note, where: n.status == ^status)
    |> Repo.all()
  end

  def get_note!(id), do: Repo.get!(Note, id)

  def get_note(id), do: Repo.get(Note, id)

  def create_note(attrs \\ %{}) do
    %Note{}
    |> Note.changeset(attrs)
    |> Repo.insert()
  end

  def update_note(%Note{} = note, attrs) do
    note
    |> Note.changeset(attrs)
    |> Repo.update()
  end

  def delete_note(%Note{} = note) do
    Repo.delete(note)
  end

  def search_notes(query) do
    search_term = "%#{query}%"

    from(n in Note,
      where: ilike(n.title, ^search_term) or ilike(n.content, ^search_term),
      order_by: [desc: n.inserted_at]
    )
    |> Repo.all()
  end

  def filter_notes_by_tags(tags) when is_list(tags) do
    from(n in Note,
      where: fragment("? && ?", n.tags, ^tags),
      order_by: [desc: n.inserted_at]
    )
    |> Repo.all()
  end
end