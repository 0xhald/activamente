defmodule Activamente.Repo.Migrations.CreateNotes do
  use Ecto.Migration

  def change do
    create table(:notes, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :content, :text, null: false
      add :tags, {:array, :string}, default: []
      add :priority, :string, default: "normal"  # low, normal, high
      add :status, :string, default: "active"    # active, completed, archived
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:notes, [:status])
    create index(:notes, [:priority])
    create index(:notes, [:tags], using: :gin)
    create index(:notes, [:title])
  end
end