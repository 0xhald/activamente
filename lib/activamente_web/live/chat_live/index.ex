defmodule ActivamenteWeb.ChatLive.Index do
  use ActivamenteWeb, :live_view

  alias Activamente.{Conversations, Documents}
  alias Activamente.AI.{RAGPipeline, ChunkingService, EmbeddingService}
  
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    # Create a new conversation or get existing one
    {:ok, conversation} = Conversations.create_conversation(%{title: "New Chat"})

    socket =
      socket
      |> assign(:conversation_id, conversation.id)
      |> assign(:messages, [])
      |> assign(:input_message, "")
      |> assign(:loading, false)
      |> assign(:uploaded_files, [])
      |> allow_upload(:documents,
        accept: ~w(.txt .csv .md),
        max_entries: 5,
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    if String.trim(content) != "" do
      socket =
        socket
        |> assign(:input_message, "")
        |> assign(:loading, true)

      # Add user message to display immediately
      user_message = %{
        role: "user",
        content: content,
        id: UUID.uuid4(),
        inserted_at: DateTime.utc_now()
      }

      messages = socket.assigns.messages ++ [user_message]
      socket = assign(socket, :messages, messages)

      # Send async request to get AI response
      send(self(), {:get_ai_response, content})

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate_message", %{"message" => %{"content" => content}}, socket) do
    {:noreply, assign(socket, :input_message, content)}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("upload_files", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :documents, fn %{path: path}, entry ->
        filename = entry.client_name
        content_type = entry.client_type || "text/plain"
        file_size = entry.client_size || 0

        # Read file content
        content = File.read!(path)

        # Create document record
        case Documents.create_document(%{
               filename: filename,
               content_type: content_type,
               file_size: file_size,
               original_content: content,
               file_path: path
             }) do
          {:ok, document} ->
            # Process document in background
            process_document_async(document)
            {:ok, %{document: document, filename: filename}}

          {:error, _changeset} ->
            {:error, "Failed to upload #{filename}"}
        end
      end)

    # Extract messages from uploads (consume_uploaded_entries returns the inner content directly)
    success_messages =
      uploaded_files
      |> Enum.filter(&is_map/1)
      |> Enum.map(fn %{filename: filename} ->
        "✓ #{filename} uploaded successfully"
      end)

    error_messages =
      uploaded_files
      |> Enum.filter(&is_binary/1)
      |> Enum.map(fn message -> "✗ #{message}" end)

    all_messages = success_messages ++ error_messages

    socket =
      if length(all_messages) > 0 do
        system_message = %{
          role: "system",
          content: Enum.join(all_messages, "\n"),
          id: UUID.uuid4(),
          inserted_at: DateTime.utc_now()
        }

        messages = socket.assigns.messages ++ [system_message]
        assign(socket, :messages, messages)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:get_ai_response, user_message}, socket) do
    case RAGPipeline.answer_question(user_message, socket.assigns.conversation_id) do
      {:ok, %{response: response}} ->
        ai_message = %{
          role: "assistant",
          content: response["content"],
          id: UUID.uuid4(),
          inserted_at: DateTime.utc_now()
        }

        messages = socket.assigns.messages ++ [ai_message]

        socket =
          socket
          |> assign(:messages, messages)
          |> assign(:loading, false)

        {:noreply, socket}

      {:error, reason} ->
        error_message = %{
          role: "system",
          content: "Error: #{reason}",
          id: UUID.uuid4(),
          inserted_at: DateTime.utc_now()
        }

        messages = socket.assigns.messages ++ [error_message]

        socket =
          socket
          |> assign(:messages, messages)
          |> assign(:loading, false)

        {:noreply, socket}
    end
  end

  defp process_document_async(document) do
    # Chunk the document
    chunks =
      case document.content_type do
        "text/csv" ->
          ChunkingService.chunk_csv(document.original_content)

        _ ->
          ChunkingService.chunk_text(document.original_content)
      end

    # Create chunk records
    chunks
    |> Enum.each(fn chunk_data ->
      Documents.create_chunk(Map.put(chunk_data, :document_id, document.id))
    end)

    # Generate embeddings for the document chunks
    case EmbeddingService.generate_embeddings_for_document(document.id) do
      {:ok, _chunks} ->
        Logger.info("Successfully generated embeddings for document #{document.id}")

      {:partial_success, successful_chunks, errors} ->
        Logger.warning("Partial success generating embeddings for document #{document.id}: #{length(successful_chunks)} successful, #{length(errors)} failed")

      {:error, reason} ->
        Logger.error("Failed to generate embeddings for document #{document.id}: #{reason}")
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex flex-col h-screen bg-gray-50">
      <!-- Header -->
      <div class="bg-white shadow-sm border-b px-6 py-4">
        <h1 class="text-2xl font-bold text-gray-900">ActivaMente AI Assistant</h1>
        <p class="text-sm text-gray-600">Ask questions about your uploaded documents</p>
      </div>
      
    <!-- File Upload Area -->
      <div class="bg-white border-b px-6 py-4">
        <div class="max-w-2xl">
          <form phx-submit="upload_files" phx-change="validate_upload">
            <div
              class="border-2 border-dashed border-gray-300 rounded-lg p-6 text-center hover:border-gray-400 transition-colors"
              phx-drop-target={@uploads.documents.ref}
            >
              <div class="space-y-2">
                <svg
                  class="mx-auto h-12 w-12 text-gray-400"
                  stroke="currentColor"
                  fill="none"
                  viewBox="0 0 48 48"
                >
                  <path
                    d="M28 8H12a4 4 0 00-4 4v20m32-12v8m0 0v8a4 4 0 01-4 4H12a4 4 0 01-4-4v-4m32-4l-3.172-3.172a4 4 0 00-5.656 0L28 28M8 32l9.172-9.172a4 4 0 015.656 0L28 28m0 0l4 4m4-24h8m-4-4v8m-12 4h.02"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                </svg>
                <div class="text-gray-600">
                  <label class="cursor-pointer">
                    <span class="font-medium text-blue-600 hover:text-blue-500">Upload files</span>
                    <span> or drag and drop</span>
                    <.live_file_input upload={@uploads.documents} class="sr-only" />
                  </label>
                </div>
                <p class="text-xs text-gray-500">TXT, CSV, MD up to 10MB each</p>
              </div>
            </div>

            <%= if length(@uploads.documents.entries) > 0 do %>
              <div class="mt-4 space-y-2">
                <%= for entry <- @uploads.documents.entries do %>
                  <div class="flex items-center justify-between p-2 bg-gray-50 rounded">
                    <span class="text-sm text-gray-700">{entry.client_name}</span>
                    <button
                      type="button"
                      phx-click="cancel_upload"
                      phx-value-ref={entry.ref}
                      class="text-red-500 hover:text-red-700"
                    >
                      ✕
                    </button>
                  </div>
                <% end %>
                <button
                  type="submit"
                  class="w-full bg-blue-600 text-white py-2 px-4 rounded hover:bg-blue-700"
                  disabled={length(@uploads.documents.entries) == 0}
                >
                  Upload Files
                </button>
              </div>
            <% end %>
          </form>
        </div>
      </div>
      
    <!-- Messages Area -->
      <div class="flex-1 overflow-y-auto px-6 py-4 space-y-4">
        <%= for message <- @messages do %>
          <div class={[
            "max-w-3xl",
            if message.role == "user" do
              "ml-auto"
            else
              "mr-auto"
            end
          ]}>
            <div class={[
              "rounded-lg px-4 py-3 shadow-sm",
              case message.role do
                "user" -> "bg-blue-600 text-white"
                "assistant" -> "bg-white border"
                "system" -> "bg-yellow-50 border border-yellow-200 text-yellow-800"
              end
            ]}>
              <div class="whitespace-pre-wrap">{message.content}</div>
              <div class="text-xs opacity-70 mt-2">
                {message.role} • {Calendar.strftime(message.inserted_at, "%H:%M")}
              </div>
            </div>
          </div>
        <% end %>

        <%= if @loading do %>
          <div class="max-w-3xl mr-auto">
            <div class="bg-white border rounded-lg px-4 py-3 shadow-sm">
              <div class="flex items-center space-x-2">
                <div class="animate-spin rounded-full h-4 w-4 border-b-2 border-blue-600"></div>
                <span class="text-gray-500">AI is thinking...</span>
              </div>
            </div>
          </div>
        <% end %>
      </div>
      
    <!-- Input Area -->
      <div class="bg-white border-t px-6 py-4">
        <form phx-submit="send_message" phx-change="validate_message" class="max-w-4xl mx-auto">
          <div class="flex space-x-4">
            <div class="flex-1">
              <input
                type="text"
                name="message[content]"
                value={@input_message}
                placeholder="Ask a question about your documents..."
                class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                disabled={@loading}
              />
            </div>
            <button
              type="submit"
              disabled={@loading or String.trim(@input_message) == ""}
              class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              Send
            </button>
          </div>
        </form>
      </div>
    </div>
    """
  end
end
