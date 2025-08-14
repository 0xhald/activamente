defmodule Activamente.Documents do
  @moduledoc """
  Context for managing documents and their chunks.
  """

  import Ecto.Query, warn: false
  alias Activamente.Repo
  alias Activamente.Documents.{Document, DocumentChunk}

  def list_documents do
    Repo.all(Document)
  end

  def get_document!(id), do: Repo.get!(Document, id)

  def get_document(id), do: Repo.get(Document, id)

  def create_document(attrs \\ %{}) do
    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
  end

  def update_document(%Document{} = document, attrs) do
    document
    |> Document.changeset(attrs)
    |> Repo.update()
  end

  def delete_document(%Document{} = document) do
    Repo.delete(document)
  end

  def change_document(%Document{} = document, attrs \\ %{}) do
    Document.changeset(document, attrs)
  end

  def create_chunk(attrs \\ %{}) do
    %DocumentChunk{}
    |> DocumentChunk.changeset(attrs)
    |> Repo.insert()
  end

  def get_chunks_for_document(document_id) do
    from(c in DocumentChunk,
      where: c.document_id == ^document_id,
      order_by: [asc: c.chunk_index]
    )
    |> Repo.all()
  end

  def search_similar_chunks(embedding, limit \\ 5) do
    from(c in DocumentChunk,
      where: not is_nil(c.embedding),
      order_by: fragment("? <=> ?", c.embedding, ^embedding),
      limit: ^limit,
      preload: [:document]
    )
    |> Repo.all()
  end

  def mark_document_processed(document_id, chunks_count) do
    document = get_document!(document_id)
    update_document(document, %{processed: true, chunks_count: chunks_count})
  end

  def update_chunk(%DocumentChunk{} = chunk, attrs) do
    chunk
    |> DocumentChunk.changeset(attrs)
    |> Repo.update()
  end
end