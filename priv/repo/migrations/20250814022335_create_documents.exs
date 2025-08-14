defmodule Activamente.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer, null: false
      add :original_content, :text, null: false
      add :processed, :boolean, default: false, null: false
      add :chunks_count, :integer, default: 0
      add :file_path, :string

      timestamps()
    end

    create index(:documents, [:processed])
    create index(:documents, [:filename])
  end
end
