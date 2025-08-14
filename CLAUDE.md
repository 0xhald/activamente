# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Setup
- `mix setup` - Install dependencies and set up the database (equivalent to `deps.get`, `ecto.setup`, `assets.setup`, `assets.build`)

### Database
- `mix ecto.create` - Create the database
- `mix ecto.migrate` - Run database migrations
- `mix ecto.reset` - Drop and recreate the database with fresh migrations and seeds
- `mix ecto.setup` - Create database, run migrations, and seed data

### Development Server
- `mix phx.server` - Start the Phoenix server (accessible at http://localhost:4000)
- `iex -S mix phx.server` - Start server with interactive Elixir shell

### Testing
- `mix test` - Run the test suite (automatically creates test database and runs migrations)

### Assets
- `mix assets.setup` - Install Tailwind and esbuild if missing
- `mix assets.build` - Build assets for development
- `mix assets.deploy` - Build and minify assets for production

## Architecture

This is a Phoenix 1.8 web application with the following structure:

### Core Components
- **Phoenix Framework**: Web framework with LiveView support
- **Ecto**: Database wrapper with PostgreSQL adapter
- **Tailwind CSS**: Utility-first CSS framework
- **esbuild**: JavaScript bundler
- **LiveView**: Real-time web interfaces without JavaScript

### Application Structure
- `lib/activamente/` - Core business logic and contexts
  - `ai/` - AI-related functionality (currently empty)
  - `application.ex` - OTP application supervisor
  - `repo.ex` - Database repository
  - `mailer.ex` - Email functionality via Swoosh
- `lib/activamente_web/` - Web interface layer
  - `live/` - LiveView modules for real-time features
    - `chat_live/` - Chat functionality (structure exists)
    - `document_live/` - Document handling (structure exists)
  - `controllers/` - HTTP request handlers
  - `components/` - Reusable UI components
  - `endpoint.ex` - HTTP endpoint configuration
  - `router.ex` - URL routing

### Database
- Uses PostgreSQL with Ecto migrations
- Current state: Only has `schema_migrations` table (fresh project)
- Seeds file available at `priv/repo/seeds.exs`

### Configuration
- Environment-specific configs in `config/` directory
- Development features: LiveDashboard, code reloading, Swoosh mailbox preview

## Implementation Status

✅ **Completed Features:**
- **RAG Pipeline**: Document upload, chunking, embedding generation, and semantic search
- **Chat Interface**: Real-time LiveView chat with file upload support  
- **Function Calling**: AI tools for notes, search, and weather information
- **Database Schema**: Documents, conversations, messages, notes with pgvector support
- **API Endpoints**: REST API for external integrations
- **Background Jobs**: Oban integration for async processing

## Quick Start
1. Set environment variables: `OPENAI_API_KEY` and/or `ANTHROPIC_API_KEY`
2. Run `mix setup` to install dependencies and create database
3. Start server with `mix phx.server`
4. Access chat interface at http://localhost:4000/chat

The application is now fully functional and ready for use!