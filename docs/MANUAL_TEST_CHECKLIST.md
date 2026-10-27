# Manual test checklist

Run every section on **both** targets unless marked:

- **APK:** the installed release build (`build/app/outputs/flutter-apk/app-release.apk`), not `flutter run`.
- **Web:** dentrascan.site, or a local release build served with `python serve.py`, in desktop Chrome. Repeat the key sections in a phone browser.

Which Rabi you get depends on the build:

- **Backend build:** `.env` has `API_BASE_URL`, like the live site. Sign-in is required and Rabi answers through `/api/ai/chat`.
- **Demo build:** no `API_BASE_URL`, with `GEMINI_API_KEY` set. Demo login, and Rabi calls Gemini directly. Use this build only for a local or APK demo, never for the public site.

Mark each item ✅ / ❌ and note the device, browser and build.

## 1. Map and markers
- [ ] Open **Clinics** with location **allowed**. The map shows tiles, the round "you" dot and clinic pins with initials.
- [ ] Tap a pin. Its card is highlighted and scrolls into view.
- [ ] Tap the locate button. The map recenters.
- [ ] **Deny** location (app settings, or the browser's site permission), then reopen Clinics. The list still loads around Manila with "Approximate distances". Tapping locate shows a message about turning location on.
- [ ] If you see "Map unavailable": web → open DevTools ▸ Console and copy the Google error. APK → run `adb logcat | grep -i maps`. Send it to whoever manages the Google Cloud key.
- [ ] Open a clinic, then Directions. Google Maps opens.

## 2. Filters and sort
- [ ] Distance **1 / 3 / 5 / 10 km**: the count and the list change, and the radius circle on the map changes.
- [ ] Rating **Any / 3.5+ / 4.0+ / 4.5+**: lower-rated clinics disappear.
- [ ] Budget **Any / Est. up to ₱500 / ₱1,000 / ₱1,500**: the list shrinks at the lower amounts.
- [ ] Sort **Nearest / Top rated / Lowest est. price**: the order changes, and the map doesn't jump.
- [ ] A combination with no matches shows "No clinics match your filters", and **Reset filters** brings them back.
- [ ] The filter badge counts active filters. Search text plus a filter works.
- [ ] Clinic detail: prices read **"Est. ₱…"**, with "Estimated prices" and the "not this clinic's rates" note.

## 3. Rabi
On each build:
- [ ] Dental question ("Why do my gums bleed?"): the typing dots appear at once. Demo build: the text appears gradually within about 1–2 s. Backend build: the reply arrives in one piece until the server streams.
- [ ] Non-dental question ("Who won the World Cup?"): a polite dental-only redirect.
- [ ] "Find a dentist near me": points to the Clinics tab or asks your area, and invents no clinic names.
- [ ] "General information only, not a diagnosis." shows under the input.
- [ ] Turn on airplane mode and ask. A friendly error with **Retry** appears, then Retry works once you're back online.
- [ ] A long chat (10+ questions) still answers quickly.
- [ ] **APK specifically:** Rabi answers at all. This was broken before the INTERNET permission fix.

## 4. Delete-chat confirmation
- [ ] History ▸ open a chat ▸ delete icon: the "Delete this chat?" dialog appears. Cancel keeps the chat, Delete removes it.
- [ ] History ▸ swipe a chat left: the same dialog appears. Cancel slides it back.
- [ ] "Delete all chats" still asks first.

## 5. Scan
- [ ] Add a **real close-up mouth photo** (lips pulled back, good light). It shows "Checking quality…", then a green check.
- [ ] Add a **non-tooth photo** (room, landscape, document). It shows the red "No teeth found · Retake" strip and a message, and the region doesn't count.
- [ ] Tap **Retake** on that card and add a mouth photo. It passes.
- [ ] Open the rejected region's detail sheet. It shows the retake note and a **Retake Photo** button.
- [ ] With only rejected photos, **Start scan** stays disabled.
- [ ] **Use Sample Photos** fills empty or rejected regions and every sample passes.
- [ ] The results page shows **"Demo result · simulated analysis"** at the top.
- [ ] Try 3–5 real mouth photos from different phones and lighting, and note any that are wrongly rejected. The thresholds are at the top of `lib/features/scan/services/tooth_photo_check.dart`.

## 6. Profile and splash
- [ ] Home ▸ tap the avatar (top right). Edit Profile opens. Save shows "Profile updated." and a notification.
- [ ] Cold start: the splash lasts about 2 s, not 3.

## 7. Desktop zoom (web, desktop browser only)
- [ ] Home ▸ Teeth (3D explorer). The mouse wheel zooms the model and the page doesn't scroll.
- [ ] Laptop trackpad pinch zooms the model.
- [ ] The + / − buttons work, and stay visible with the window made short.
- [ ] The hint reads "Drag to rotate · scroll to zoom".

## 8. Regression
- [ ] Sign up with a new email: the OTP arrives, and verifying works.
- [ ] Wait 10+ minutes before entering the OTP: it's rejected as expired, and resend works.
- [ ] Log out, then log in. Wrong password shows an error.
- [ ] Forgot or change password works, and the new password logs in.
- [ ] Google sign-in (if enabled on that build).
- [ ] Notifications: the bell count updates, and opening one marks it read.
- [ ] History calendar shows past scans on the right days.
