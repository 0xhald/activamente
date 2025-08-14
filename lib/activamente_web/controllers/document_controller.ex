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

  def upload(conn, %{"document" => %Plug.Upload{} = upload}) do
    case create_document_from_upload(upload) do
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

  def upload(conn, %{"file" => file_params}) when is_map(file_params) do
    case create_document_from_json(file_params) do
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

  defp create_document_from_upload(%Plug.Upload{
    filename: filename,
    content_type: content_type,
    path: temp_path
  }) do
    case File.read(temp_path) do
      {:ok, content} ->
        Documents.create_document(%{
          filename: filename,
          content_type: content_type,
          file_size: String.length(content),
          original_content: content,
          file_path: temp_path
        })

      {:error, reason} ->
        {:error, "Could not read uploaded file: #{reason}"}
    end
  end

  defp create_document_from_json(%{
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