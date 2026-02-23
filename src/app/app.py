from dotenv import load_dotenv
from openai import AsyncOpenAI
import chainlit as cl
import os

load_dotenv()

client = AsyncOpenAI(
    base_url=os.getenv("MODEL_BASE_URL"), api_key=os.getenv("MODEL_API_KEY")
)

cl.instrument_openai()

settings = {
    "model": os.getenv("MODEL_NAME"),
    "temperature": 0.4,
    "max_tokens": 256,
    "top_p": 0.9,
    "frequency_penalty": 0.3,
    "presence_penalty": 0,
}


@cl.on_message
async def on_message(message: cl.Message):
    response = await client.chat.completions.create(
        messages=[
            {
                "content": "You are a helpful bot. Answer questions clearly and briefly. Use simple words and short sentences. Stay on topic. If you do not know the answer, say so.",
                "role": "system",
            },
            {"content": message.content, "role": "user"},
        ],
        stream=True,
        **settings
    )
    msg = cl.Message(content="")
    async for chunk in response:
        if chunk.choices[0].delta.content:
            await msg.stream_token(chunk.choices[0].delta.content)
    await msg.send()
