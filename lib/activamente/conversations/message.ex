defmodule Activamente.Conversations.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "messages" do
    field :role, :string
    field :content, :string
    field :metadata, :map, default: %{}
    field :function_call, :map
    field :function_result, :map

    belongs_to :conversation, Activamente.Conversations.Conversation

    timestamps()
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:conversation_id, :role, :content, :metadata, :function_call, :function_result])
    |> validate_required([:conversation_id, :role, :content])
    |> validate_inclusion(:role, ["user", "assistant", "system"])
    |> foreign_key_constraint(:conversation_id)
  end
end