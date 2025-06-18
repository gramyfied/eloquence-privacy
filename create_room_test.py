from livekit import api
import asyncio
import os

LIVEKIT_URL = os.getenv("LIVEKIT_URL", "ws://livekit:7880")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY", "devkey")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET", "devsecret")

async def main():
  print(f"Using LiveKit URL: {LIVEKIT_URL}")
  print(f"Using LiveKit API Key: {LIVEKIT_API_KEY}")
  # The LiveKitAPI constructor now correctly takes the API key and secret
  # directly, not from environment variables by default for explicit creation.
  # So, explicitly pass them.
  lkapi = api.LiveKitAPI(LIVEKIT_URL, LIVEKIT_API_KEY, LIVEKIT_API_SECRET) 
  try:
    room_name = "test-room-api-created"
    req = api.CreateRoomRequest(name=room_name)
    room_info = await lkapi.room.create_room(req)
    print(f"Room created successfully: {room_info}")
    # Clean up: delete the room after creation
    await lkapi.room.delete_room(api.DeleteRoomRequest(room=room_name))
    print(f"Room {room_name} deleted successfully.")
  except api.ApiException as e:
    print(f"LiveKit API Exception: {e.status} - {e.body}")
  except Exception as e:
    print(f"An unexpected error occurred: {e}")
  finally:
    await lkapi.aclose()

asyncio.run(main())