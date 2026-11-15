# Rabi backend handoff (`POST /api/ai/chat`)

The live site (dentrascan.site) runs in backend mode, so **every** Rabi answer there comes from this endpoint. The app has been updated. The server needs the changes below for the speed and behavior fixes to reach users.

## 1. System prompt: use these rules

Copy the full prompt from `lib/core/services/gemini_service.dart` (`_systemInstruction`). Its key rules:

- **Dental only.** For a non-dental question, reply in one or two friendly sentences that Rabi focuses on dental topics, and offer an example dental question. Don't answer the off-topic question.
- **No invented clinics.** Rabi doesn't know the user's location. For "a clinic near me", point to the **Clinics tab** (it lists nearby clinics once location is on), or ask which city or area they're in. Never make up clinic names, addresses or prices.
- **General information, not a diagnosis.** The app shows this note under the chat box, so don't repeat a disclaimer in every answer. Do say "see a dentist soon" for urgent signs (severe pain, swelling, fever, bleeding that won't stop, trauma).
- Short answers: a brief reply first, then a few bullets. No headings or tables.

## 2. Request the app now sends

Headers: `Authorization: Bearer <token>`, `Accept: text/event-stream, application/json`

```json
{ "session_id": "…", "message": "…", "prompt": "… (optional)",
  "history": [ { "role": "user" | "model", "text": "…" } ] }
```

`history` is new. It holds at most the **last 8 answered turns** and starts on a user turn. If the server already stores the conversation by `session_id`, it can ignore `history`. Either way, send the model **no more than 8 earlier turns**.

## 3. Response: either style works

- **JSON (today's behavior, still supported):** `200 {"reply": "…"}`
- **Streaming (recommended, faster first text):** `Content-Type: text/event-stream`, one event per chunk:
  `data: {"delta": "next piece of text"}` … then `data: [DONE]`
- **Errors:** a non-2xx status with `{"error": {"code": "ai_failed", "message": "Text safe to show the user."}}`. Mid-stream, send `data: {"error": {"message": "…"}}`. The app shows `message` as is, so never put raw Gemini errors, keys or quota details in it.

## 4. Timing

- The app gives up if nothing arrives within **15 s**, or if a stream goes quiet for **12 s**. It then shows "Rabi is taking too long to answer" with a retry.
- Set the server's own Gemini timeout to about **12–14 s**, so the user gets your clear error instead of the app's timeout.
- **Target:** first text within 1–3 s. Measured direct to Gemini (`gemini-3.5-flash-lite`, streaming): first text at about 0.75 s, full reply at about 2.2 s.

## 5. Gemini key

- The key must live **only on the server**. The live site's bundled `.env` has no Gemini key at the moment, which is correct.
- Anything in the web `.env` is public, at `https://dentrascan.site/assets/.env`. Never add `GEMINI_API_KEY` to the `.env` used for a web deploy.
- If any past deploy ever included it, rotate the key.

## 6. Test checklist (after your changes)

- [ ] Dental question: a short answer, first text within 3 s
- [ ] "What's the capital of France?": a polite dental-only redirect, no answer
- [ ] "Find a dentist near me": suggests the Clinics tab or asks for the area, no made-up clinics
- [ ] A request with 20 turns of `history`: the model sees at most 8
- [ ] Simulate a Gemini failure or timeout: a non-2xx with `error.message`, returned within 15 s
- [ ] If streaming: `curl -N` shows `data: {"delta": …}` lines arriving one by one, then `data: [DONE]`
- [ ] The app (signed in) shows text appearing gradually; delete-chat and history still work

## Account deletion OTP (frontend integration required)

The delete-account screen now requests and verifies a one-time code before calling the existing account deletion operation. The UI currently uses `MockDeletionOtpRepository` (demo code `123456`); replace it with an API-backed implementation when the backend is ready.

Required authenticated endpoints:

- `POST /api/auth/account-deletion/otp` — send a short-lived deletion code to the signed-in account email. Return `200` with a generic success response; apply rate limits and avoid revealing whether an email exists.
- `POST /api/auth/account-deletion/otp/verify` — accept `{ "code": "123456" }`, bind verification to the authenticated account and a short expiry, and return a short-lived deletion authorization token (or equivalent server-side verified state).
- `DELETE /api/users/me` — the app already calls this route. Require the deletion authorization token from OTP verification, delete the account and associated data, and return success only after deletion is committed.

Use the backend's standard error envelope for invalid, expired, and rate-limited codes. The frontend's deletion-data wording is marked for team confirmation in `delete_account_dialog.dart`.
