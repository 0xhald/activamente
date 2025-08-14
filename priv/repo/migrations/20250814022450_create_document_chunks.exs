defmodule Activamente.Repo.Migrations.CreateDocumentChunks do
  use Ecto.Migration

  def change do
    create table(:document_chunks, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :document_id, references(:documents, type: :binary_id, on_delete: :delete_all), null: false
      add :chunk_index, :integer, null: false
      add :content, :text, null: false
      add :embedding, :vector, size: 1536, null: true
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:document_chunks, [:document_id])
    create index(:document_chunks, [:chunk_index])
    create index(:document_chunks, [:embedding], using: :ivfflat)
  end
end