# ActivaMente AI Assistant - Deployment Guide

## Prerequisites

1. **API Keys**: Obtain API keys from OpenAI and/or Anthropic
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
- `ANTHROPIC_API_KEY`: Your Anthropic API key (starts with `sk-ant-`) - optional

### 4. Start the Application
```bash
mix phx.server
```

Access the application at: http://localhost:4000

## Production Deployment

### Option 1: Fly.io Deployment

1. **Install Fly CLI**
```bash
curl -L https://fly.io/install.sh | sh
```

2. **Initialize Fly App**
```bash
fly launch
```

3. **Set Environment Variables**
```bash
fly secrets set OPENAI_API_KEY=sk-proj-your-key-here
fly secrets set ANTHROPIC_API_KEY=sk-ant-your-key-here
fly secrets set DATABASE_URL=your-postgres-url
fly secrets set SECRET_KEY_BASE=$(mix phx.gen.secret)
```

4. **Deploy**
```bash
fly deploy
```

### Option 2: Docker Deployment

1. **Build Docker Image**
```bash
docker build -t activamente .
```

2. **Run with Environment Variables**
```bash
docker run -p 4000:4000 \
  -e OPENAI_API_KEY=sk-proj-your-key \
  -e DATABASE_URL=postgresql://... \
  -e SECRET_KEY_BASE=$(mix phx.gen.secret) \
  activamente
```

### Option 3: AWS/GCP/Azure

Deploy using your preferred cloud provider's container service:
- AWS ECS/Fargate
- Google Cloud Run
- Azure Container Instances

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

## Monitoring & Maintenance

### Health Checks
- Endpoint: `GET /health` (implement if needed)
- Database connectivity
- API key validation

### Logs
Monitor application logs for:
- API rate limits
- Database connection issues
- Embedding generation failures

### Scaling Considerations
- Database connection pooling (configured via Ecto)
- Background job processing (Oban)
- API rate limiting for external services

## Security

1. **API Keys**: Store securely in environment variables
2. **Database**: Use connection encryption
3. **File Uploads**: Validate file types and sizes
4. **CORS**: Configure appropriately for your domain

## Support

For issues and questions:
- Check logs for error messages
- Verify API key configuration
- Ensure pgvector extension is installed
- Monitor database connection status