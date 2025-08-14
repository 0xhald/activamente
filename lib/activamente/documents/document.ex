defmodule Activamente.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "documents" do
    field :filename, :string
    field :content_type, :string
    field :file_size, :integer
    field :original_content, :string
    field :processed, :boolean, default: false
    field :chunks_count, :integer, default: 0
    field :file_path, :string

    has_many :chunks, Activamente.Documents.DocumentChunk, foreign_key: :document_id

    timestamps()
  end

  @doc false
  def changeset(document, attrs) do
    document
    |> cast(attrs, [:filename, :content_type, :file_size, :original_content, :processed, :chunks_count, :file_path])
    |> validate_required([:filename, :content_type, :file_size, :original_content])
    |> validate_length(:filename, min: 1, max: 255)
    |> validate_number(:file_size, greater_than: 0)
  end
end