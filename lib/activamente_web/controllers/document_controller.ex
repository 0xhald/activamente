defmodule ActivamenteWeb.DocumentController do
  use ActivamenteWeb, :controller

  alias Activamente.Documents

  def index(conn, _params) do
    documents = Documents.list_documents()
    
    formatted_documents = 
      documents
      |> Enum.map(fn doc ->
        %{
          id: doc.id,
          filename: doc.filename,
          content_type: doc.content_type,
          file_size: doc.file_size,
          processed: doc.processed,
          chunks_count: doc.chunks_count,
          inserted_at: doc.inserted_at
        }
      end)

    json(conn, %{documents: formatted_documents})
  end

  def upload(conn, %{"file" => file_params}) do
    case create_document_from_upload(file_params) do
      {:ok, document} ->
        json(conn, %{
          success: true,
          document: %{
            id: document.id,
            filename: document.filename,
            content_type: document.content_type,
            file_size: document.file_size,
            processed: document.processed
          }
        })

      {:error, changeset} ->
        errors = 
          changeset.errors
          |> Enum.map(fn {field, {message, _}} -> "#{field}: #{message}" end)

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Upload failed", details: errors})
    end
  end

  defp create_document_from_upload(%{
    "filename" => filename,
    "content" => content,
    "content_type" => content_type
  }) do
    Documents.create_document(%{
      filename: filename,
      content_type: content_type,
      file_size: String.length(content),
      original_content: content
    })
  end

  defp create_document_from_upload(_), do: {:error, "Invalid file parameters"}
end