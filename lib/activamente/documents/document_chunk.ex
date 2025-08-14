defmodule Activamente.Documents.DocumentChunk do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "document_chunks" do
    field :chunk_index, :integer
    field :content, :string
    field :embedding, Pgvector.Ecto.Vector
    field :metadata, :map, default: %{}

    belongs_to :document, Activamente.Documents.Document

    timestamps()
  end

  @doc false
  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:document_id, :chunk_index, :content, :embedding, :metadata])
    |> validate_required([:document_id, :chunk_index, :content])
    |> validate_number(:chunk_index, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:document_id)
  end
end