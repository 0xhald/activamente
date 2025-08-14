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
        max_file_size: 10_000_000,
        auto_upload: true,
        progress: &handle_progress/3
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
  def handle_event("suggest_message", %{"message" => message}, socket) do
    {:noreply, assign(socket, :input_message, message)}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    # This event is triggered when files are selected, allowing Phoenix to validate them
    {:noreply, socket}
  end

  @impl true
  def handle_progress(:documents, entry, socket) do
    if entry.done? do
      # File upload is complete, process it
      uploaded_file = 
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
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
              {:ok, filename}

            {:error, _changeset} ->
              {:error, "Failed to upload #{filename}"}
          end
        end)

      # Add system message about upload
      message_content = case uploaded_file do
        {:ok, filename} -> "✓ #{filename} uploaded successfully"
        {:error, error} -> "✗ #{error}"
        filename when is_binary(filename) -> "✓ #{filename} uploaded successfully"
        _ -> "✗ Upload failed"
      end

      system_message = %{
        role: "system",
        content: message_content,
        id: UUID.uuid4(),
        inserted_at: DateTime.utc_now()
      }

      messages = socket.assigns.messages ++ [system_message]
      {:noreply, assign(socket, :messages, messages)}
    else
      {:noreply, socket}
    end
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

  defp format_file_size(size) when is_integer(size) do
    cond do
      size < 1024 -> "#{size} B"
      size < 1024 * 1024 -> "#{Float.round(size / 1024, 1)} KB"
      size < 1024 * 1024 * 1024 -> "#{Float.round(size / (1024 * 1024), 1)} MB"
      true -> "#{Float.round(size / (1024 * 1024 * 1024), 1)} GB"
    end
  end

  defp format_file_size(_), do: "Unknown size"

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
    <div class="flex flex-col h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50">
      <!-- Enhanced Header -->
      <header class="bg-white/80 backdrop-blur-sm shadow-lg border-b border-blue-100 px-6 py-6">
        <div class="flex items-center justify-between max-w-6xl mx-auto">
          <div class="flex items-center space-x-4">
            <div class="p-2 bg-blue-600 rounded-xl shadow-lg">
              <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
              </svg>
            </div>
            <div>
              <h1 class="text-3xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 bg-clip-text text-transparent">
                ActivaMente
              </h1>
              <p class="text-sm text-gray-600 font-medium">AI-Powered Document Assistant</p>
            </div>
          </div>
          <div class="flex items-center space-x-3">
            <div class="hidden sm:flex items-center space-x-2 text-sm text-gray-500">
              <div class="w-2 h-2 bg-green-500 rounded-full animate-pulse"></div>
              <span>AI Ready</span>
            </div>
          </div>
        </div>
      </header>
      
      <!-- Enhanced Messages Area -->
      <div class="flex-1 overflow-y-auto px-6 py-6">
        <div class="max-w-4xl mx-auto space-y-6">
          <%= if length(@messages) == 0 do %>
            <!-- Welcome message when no messages -->
            <div class="text-center py-12">
              <div class="mb-6">
                <div class="mx-auto w-20 h-20 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center shadow-lg">
                  <svg class="w-10 h-10 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
                  </svg>
                </div>
              </div>
              <h2 class="text-2xl font-bold text-gray-800 mb-3">Welcome to ActivaMente!</h2>
              <p class="text-gray-600 mb-6 max-w-md mx-auto">Start by uploading documents or asking questions. I'm here to help you find information and insights.</p>
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4 max-w-2xl mx-auto">
                <div class="bg-white/80 rounded-xl p-4 shadow-sm border border-gray-100">
                  <div class="w-8 h-8 bg-blue-100 rounded-lg flex items-center justify-center mb-2 mx-auto">
                    <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                    </svg>
                  </div>
                  <h3 class="font-semibold text-gray-800 text-sm mb-1">Upload Documents</h3>
                  <p class="text-xs text-gray-600">Add your files to get started</p>
                </div>
                <div class="bg-white/80 rounded-xl p-4 shadow-sm border border-gray-100">
                  <div class="w-8 h-8 bg-purple-100 rounded-lg flex items-center justify-center mb-2 mx-auto">
                    <svg class="w-4 h-4 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
                    </svg>
                  </div>
                  <h3 class="font-semibold text-gray-800 text-sm mb-1">Ask Questions</h3>
                  <p class="text-xs text-gray-600">Search and explore your content</p>
                </div>
                <div class="bg-white/80 rounded-xl p-4 shadow-sm border border-gray-100">
                  <div class="w-8 h-8 bg-green-100 rounded-lg flex items-center justify-center mb-2 mx-auto">
                    <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
                    </svg>
                  </div>
                  <h3 class="font-semibold text-gray-800 text-sm mb-1">Get Insights</h3>
                  <p class="text-xs text-gray-600">Discover patterns and answers</p>
                </div>
              </div>
            </div>
          <% end %>
          
          <%= for message <- @messages do %>
            <div class={[
              "flex",
              if message.role == "user" do
                "justify-end"
              else
                "justify-start"
              end
            ]}>
              <div class={[
                "max-w-3xl",
                case message.role do
                  "user" -> "order-2"
                  _ -> "order-1"
                end
              ]}>
                <div class={[
                  "rounded-2xl px-6 py-4 shadow-sm backdrop-blur-sm",
                  case message.role do
                    "user" -> "bg-gradient-to-r from-blue-600 to-blue-700 text-white ml-auto"
                    "assistant" -> "bg-white/90 border border-gray-200 text-gray-800"
                    "system" -> "bg-gradient-to-r from-amber-50 to-yellow-50 border border-amber-200 text-amber-800"
                  end
                ]}>
                  <div class="whitespace-pre-wrap leading-relaxed">{message.content}</div>
                  <div class={[
                    "text-xs mt-3 flex items-center space-x-2",
                    case message.role do
                      "user" -> "text-blue-100"
                      _ -> "text-gray-500"
                    end
                  ]}>
                    <div class={[
                      "w-2 h-2 rounded-full",
                      case message.role do
                        "user" -> "bg-blue-300"
                        "assistant" -> "bg-green-500"
                        "system" -> "bg-amber-500"
                      end
                    ]}></div>
                    <span class="capitalize font-medium">{message.role}</span>
                    <span>•</span>
                    <span>{Calendar.strftime(message.inserted_at, "%H:%M")}</span>
                  </div>
                </div>
              </div>
              
              <!-- Avatar -->
              <div class={[
                "flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center ml-3 mr-3",
                case message.role do
                  "user" -> "order-1 bg-gradient-to-br from-blue-500 to-blue-600"
                  "assistant" -> "order-2 bg-gradient-to-br from-purple-500 to-purple-600"
                  "system" -> "order-2 bg-gradient-to-br from-amber-500 to-yellow-500"
                end
              ]}>
                <svg class="w-5 h-5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <%= case message.role do %>
                    <% "user" -> %>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                    <% "assistant" -> %>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
                    <% "system" -> %>
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                  <% end %>
                </svg>
              </div>
            </div>
          <% end %>

          <%= if @loading do %>
            <div class="flex justify-start">
              <div class="max-w-3xl order-1">
                <div class="bg-white/90 border border-gray-200 rounded-2xl px-6 py-4 shadow-sm backdrop-blur-sm">
                  <div class="flex items-center space-x-3">
                    <div class="relative">
                      <div class="animate-spin rounded-full h-6 w-6 border-2 border-blue-200 border-t-blue-600"></div>
                      <div class="absolute inset-0 rounded-full bg-blue-100 animate-pulse opacity-25"></div>
                    </div>
                    <div>
                      <span class="text-gray-700 font-medium">AI is analyzing...</span>
                      <div class="text-xs text-gray-500 mt-1">Processing your request</div>
                    </div>
                  </div>
                  <!-- Typing animation dots -->
                  <div class="flex space-x-1 mt-3 ml-9">
                    <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"></div>
                    <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.1s"></div>
                    <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s"></div>
                  </div>
                </div>
              </div>
              
              <!-- AI Avatar -->
              <div class="flex-shrink-0 w-10 h-10 rounded-full bg-gradient-to-br from-purple-500 to-purple-600 flex items-center justify-center ml-3 order-2">
                <svg class="w-5 h-5 text-white animate-pulse" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
                </svg>
              </div>
            </div>
          <% end %>
        </div>
      </div>
      
      <!-- Enhanced Input Area with File Upload -->
      <footer class="bg-white/80 backdrop-blur-sm border-t border-blue-100 px-6 py-6">
        <div class="max-w-4xl mx-auto">
          <!-- File Upload Progress -->
          <%= if length(@uploads.documents.entries) > 0 do %>
            <div class="mb-4">
              <div class="bg-blue-50/50 border border-blue-200 rounded-xl p-4">
                <h3 class="text-sm font-semibold text-gray-700 mb-3">Uploading files...</h3>
                <div class="space-y-2">
                  <%= for entry <- @uploads.documents.entries do %>
                    <div class="flex items-center justify-between p-3 bg-white rounded-lg border border-gray-200">
                      <div class="flex items-center space-x-3 flex-1">
                        <div class="w-8 h-8 bg-gradient-to-br from-blue-100 to-purple-100 rounded-lg flex items-center justify-center">
                          <%= if entry.done? do %>
                            <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                            </svg>
                          <% else %>
                            <div class="animate-spin rounded-full h-4 w-4 border-2 border-blue-200 border-t-blue-600"></div>
                          <% end %>
                        </div>
                        <div class="flex-1">
                          <div class="flex items-center justify-between">
                            <span class="text-sm font-medium text-gray-900">{entry.client_name}</span>
                            <span class="text-xs text-gray-500">{format_file_size(entry.client_size || 0)}</span>
                          </div>
                          <div class="mt-1">
                            <div class="w-full bg-gray-200 rounded-full h-2">
                              <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" style={"width: #{entry.progress}%"}></div>
                            </div>
                          </div>
                        </div>
                      </div>
                      <%= unless entry.done? do %>
                        <button
                          type="button"
                          phx-click="cancel_upload"
                          phx-value-ref={entry.ref}
                          class="p-1 text-gray-400 hover:text-red-500 hover:bg-red-50 rounded-md transition-colors ml-2"
                          title="Cancel upload"
                        >
                          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                          </svg>
                        </button>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
          
          <!-- Combined Input and Upload Area -->
          <form phx-submit="send_message" phx-change="validate_message" class="relative">
            <div
              class="flex items-end space-x-3 p-3 bg-white border-2 border-gray-200 rounded-2xl focus-within:border-blue-500 focus-within:ring-4 focus-within:ring-blue-100 transition-all duration-200 shadow-sm"
              phx-drop-target={@uploads.documents.ref}
            >
              <!-- File Upload Button -->
              <div class="flex-shrink-0">
                <form phx-change="validate_upload">
                  <label class="cursor-pointer p-2 text-gray-400 hover:text-blue-600 hover:bg-blue-50 rounded-lg transition-colors group" title="Attach files">
                    <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
                    </svg>
                    <.live_file_input upload={@uploads.documents} class="sr-only" />
                  </label>
                </form>
              </div>
              
              <!-- Text Input -->
              <div class="flex-1">
                <input
                  type="text"
                  name="message[content]"
                  value={@input_message}
                  placeholder="Ask me anything about your documents..."
                  class="w-full px-3 py-2 bg-transparent border-none focus:outline-none text-gray-800 placeholder-gray-500"
                  disabled={@loading}
                  autocomplete="off"
                />
              </div>
              
              <!-- Send Button -->
              <div class="flex-shrink-0">
                <button
                  type="submit"
                  disabled={@loading or String.trim(@input_message) == ""}
                  class="group relative p-2 bg-gradient-to-r from-blue-600 to-purple-600 text-white rounded-xl hover:from-blue-700 hover:to-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transform hover:scale-105 active:scale-95 transition-all duration-200 shadow-md hover:shadow-lg"
                  title="Send message"
                >
                  <%= if @loading do %>
                    <div class="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent"></div>
                  <% else %>
                    <svg class="w-5 h-5 transform group-hover:translate-x-0.5 transition-transform" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
                    </svg>
                  <% end %>
                </button>
              </div>
            </div>
            
            <!-- File type hints -->
            <div class="flex items-center justify-center mt-2 space-x-4 text-xs text-gray-400">
              <span class="flex items-center space-x-1">
                <div class="w-1.5 h-1.5 bg-green-500 rounded-full"></div>
                <span>TXT</span>
              </span>
              <span class="flex items-center space-x-1">
                <div class="w-1.5 h-1.5 bg-blue-500 rounded-full"></div>
                <span>CSV</span>
              </span>
              <span class="flex items-center space-x-1">
                <div class="w-1.5 h-1.5 bg-purple-500 rounded-full"></div>
                <span>MD</span>
              </span>
              <span>• Max 10MB each</span>
            </div>
          </form>
          
          <!-- Quick action suggestions -->
          <%= if length(@messages) == 0 and String.trim(@input_message) == "" and length(@uploads.documents.entries) == 0 do %>
            <div class="mt-4">
              <div class="flex flex-wrap gap-2 justify-center">
                <button type="button" phx-click="suggest_message" phx-value-message="Summarize my uploaded documents" class="px-4 py-2 bg-blue-50 text-blue-700 rounded-full text-sm font-medium hover:bg-blue-100 transition-colors border border-blue-200">
                  📄 Summarize documents
                </button>
                <button type="button" phx-click="suggest_message" phx-value-message="What are the key insights from my data?" class="px-4 py-2 bg-purple-50 text-purple-700 rounded-full text-sm font-medium hover:bg-purple-100 transition-colors border border-purple-200">
                  🔍 Find insights
                </button>
                <button type="button" phx-click="suggest_message" phx-value-message="Create a summary report" class="px-4 py-2 bg-green-50 text-green-700 rounded-full text-sm font-medium hover:bg-green-100 transition-colors border border-green-200">
                  📊 Generate report
                </button>
              </div>
            </div>
          <% end %>
        </div>
      </footer>
    </div>
    """
  end
end
