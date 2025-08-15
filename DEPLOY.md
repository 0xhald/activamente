# ActivaMente AI Assistant - Deployment Guide

## Prerequisites

1. **API Keys**: Obtain API keys from OpenAI
2. **PostgreSQL**: Database with pgvector extension
3. **Elixir/Phoenix**: Environment for running the application

## Local Development Setup

### 1. Install Dependencies
```bash
mix deps.get
mix deps.compile
```

### 2. Database Setup
Ensure PostgreSQL is running with pgvector extension:
```bash
# For Docker
docker run --name postgres-vector -p 5432:5432 -e POSTGRES_PASSWORD=postgres -d pgvector/pgvector:pg17

# Create and migrate database
mix ecto.create
mix ecto.migrate
```

### 3. Environment Configuration
Copy and configure environment variables:
```bash
cp .env.example .env
# Edit .env with your API keys
```

Required environment variables:
- `OPENAI_API_KEY`: Your OpenAI API key (starts with `sk-proj-`)

### 4. Start the Application
```bash
mix phx.server
```

Access the application at: http://localhost:4000

## Features Overview

### 1. Document Upload & Processing
- Support for TXT, CSV, MD files
- Automatic text chunking for optimal retrieval
- Vector embeddings using OpenAI's text-embedding-3-small

### 2. RAG (Retrieval-Augmented Generation)
- Semantic search using pgvector
- Context-aware responses with document citations
- Configurable similarity thresholds

### 3. Function Calling Tools
- **Notes Tool**: Create and manage notes through AI
- **Search Tool**: Search documents and notes
- **Weather Tool**: Get weather information (demo)

### 4. API Endpoints
- `POST /api/chat` - Send messages and get AI responses
- `GET /api/conversations/:id/messages` - Retrieve conversation history
- `POST /api/documents` - Upload documents
- `GET /api/documents` - List uploaded documents
- `POST /api/notes` - Create notes
- `GET /api/notes` - List notes

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Frontend      │    │    Phoenix       │    │   AI Services   │
│   (LiveView)    │───▶│   Application    │───▶│   (OpenAI/      │
│                 │    │                  │    │    Anthropic)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌──────────────────┐
                       │   PostgreSQL     │
                       │   + pgvector     │
                       └──────────────────┘
```