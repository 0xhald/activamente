# ActivaMente AI Challenge: Build a Mini AI Knowledge Assistant with RAG and Tools

## Goal

Build a small, working AI-powered assistant that can answer questions about a custom dataset using RAG (Retrieval-Augmented Generation) and expose at least one custom tool for actions (e.g., querying an API).

## Requirements

### 1. Frontend

- Simple web UI (any stack) with:
- Chat interface to talk to the assistant.
- Option to upload a text file or CSV to become the assistant's "knowledge base."

### 2. Backend / AI Logic

- Backend service (any stack) that:
- Accepts user's uploaded file, chunks text, and creates embeddings.
- Stores embeddings in a vector store (any stack).
- On query, retrieves relevant chunks and calls a LLM API (GPT-4, Claude, Gemini) with retrieved context.
- Exposes at least one custom tool (e.g., lookup, save note to x, call external API).

### 3. Integrations

- PostgreSQL/MySQL/GraphQL/any (local or AWS) for storing data.
- Strapi CMS/ any with at least one content type (e.g., "Notes" or "Tasks") and the assistant's tool can create an entry in it.

### 4. Infrastructure

- Deploy backend to AWS/local/any (Lambda, ECS, or EC2 — your choice).
- Use environment variables for API keys and configs.
- Bonus: Document deploy steps in a DEPLOY.md or send us a Notion Page.

### 5. APIs & Tools

- Must use at least one LLM API, we provide (OpenAI, Anthropic) but feel free to use any.
- Must use API call or embeddings + RAG to answer questions.
- Must implement one function/tool calling example.

## MUST READ

### Core Documentation
- [Cursor Documentation](https://docs.cursor.com/en/welcome)
- [Claude Code Overview](https://docs.anthropic.com/en/docs/claude-code/overview)
- [Anthropic MCP](https://docs.anthropic.com/en/docs/mcp)
- [Anthropic API Overview](https://docs.anthropic.com/en/api/overview)

### OpenAI Resources
- [GPT-5 Models](https://platform.openai.com/docs/models/gpt-5)
- [OpenAI Quickstart](https://platform.openai.com/docs/quickstart)
- [OpenAI Tools Guide](https://platform.openai.com/docs/guides/tools)
- [OpenAI Tools Remote MCP](https://platform.openai.com/docs/guides/tools-remote-mcp)
- [Introducing GPT-OSS](https://openai.com/es-419/index/introducing-gpt-oss/)

### Training & Learning
- [Anthropic Skilljar](https://anthropic.skilljar.com/)
- [HuggingFace Agents Course - What Are Agents](https://huggingface.co/learn/agents-course/unit1/what-are-agents)
- [HuggingFace Agents Course - Tools](https://huggingface.co/learn/agents-course/unit1/tools)

## N2H (Nice to Have)
- [ElevenLabs Overview](https://elevenlabs.io/docs/product-guides/overview)
- [HeyGen Create Video](https://docs.heygen.com/docs/create-video)
- [n8n Documentation](https://docs.n8n.io/)
- [Notion Academy](https://www.notion.com/es/help/notion-academy/course/101-introduction)
- [Moonshot AI](https://platform.moonshot.ai/docs/introduction#text-generation-model)

## API KEY

Ask for them at **david.soto@activamente.com**, WA **+525578076763** sharing GitHub handle + Name, Last Name.

### API Key Formats
- **OPEN AI**: `sk-proj-`
- **CLAUDE**: `sk-ant-`