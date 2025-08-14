defmodule Activamente.Repo.Migrations.CreateConversations do
  use Ecto.Migration

  def change do
    create table(:conversations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string
      add :metadata, :map, default: %{}

      timestamps()
    end

    create table(:messages, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :conversation_id, references(:conversations, type: :binary_id, on_delete: :delete_all), null: false
      add :role, :string, null: false  # "user", "assistant", "system"
      add :content, :text, null: false
      add :metadata, :map, default: %{}
      add :function_call, :map, null: true
      add :function_result, :map, null: true

      timestamps()
    end

    create index(:messages, [:conversation_id])
    create index(:messages, [:role])
    create index(:messages, [:inserted_at])
  end
end