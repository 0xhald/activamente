defmodule Activamente.Notes.Note do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "notes" do
    field :title, :string
    field :content, :string
    field :tags, {:array, :string}, default: []
    field :priority, :string, default: "normal"
    field :status, :string, default: "active"
    field :metadata, :map, default: %{}

    timestamps()
  end

  @doc false
  def changeset(note, attrs) do
    note
    |> cast(attrs, [:title, :content, :tags, :priority, :status, :metadata])
    |> validate_required([:title, :content])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_inclusion(:priority, ["low", "normal", "high"])
    |> validate_inclusion(:status, ["active", "completed", "archived"])
  end
end