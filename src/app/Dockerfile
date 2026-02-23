FROM python:3.12-slim AS builder

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

COPY pyproject.toml uv.lock ./

RUN uv sync --frozen --no-install-project --no-editable

COPY app.py chainlit.md ./

FROM python:3.12-slim

LABEL org.opencontainers.image.source="https://github.com/pauldotyu/aks-everywhere-demo"
LABEL org.opencontainers.image.description="Chainlit chatbot app"
LABEL org.opencontainers.image.licenses="MIT"

WORKDIR /app

COPY --from=builder /app/.venv /app/.venv
COPY --from=builder /app/app.py /app/chainlit.md ./

ENV PATH="/app/.venv/bin:$PATH"

EXPOSE 8000

CMD ["chainlit", "run", "app.py", "--host", "0.0.0.0", "--port", "8000"]
