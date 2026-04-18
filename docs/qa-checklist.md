# TalkNative Manual QA Checklist

Run before every release or significant merge.

## Capable device (iPhone 16 Pro / Apple Intelligence on)
- [ ] Fresh install → Enhance tab opens with empty textbox, 3 chips shown (Casual, Professional, Warm)
- [ ] Type < 3 chars → Enhance button enabled; tap produces 3 streamed variants
- [ ] Type 2100 chars → warning shown, button disabled
- [ ] Copy button on any variant → pasted into Notes matches
- [ ] Regenerate on one variant → only that card resets and re-fills
- [ ] Close sheet mid-stream → reopening starts fresh (no ghost state)
- [ ] Recent tab shows the new entry with relative time
- [ ] Recent → tap entry → saved variants view shows same 3 outputs
- [ ] Recent → swipe delete → entry removed
- [ ] Settings → Active presets → change to different 3 → home chips update
- [ ] Settings → Custom presets → add one with 20-char label → save succeeds
- [ ] Custom preset appears in Active-presets picker
- [ ] 20 custom presets → New Preset button disabled
- [ ] Clear history → Recent tab empty
- [ ] About and Privacy screens render and scroll

## Share extension
- [ ] From Notes → select text → Share → TalkNative → sheet opens with selected text prefilled
- [ ] From Safari → select text → Share → TalkNative → same
- [ ] From Mail → Share → TalkNative → same
- [ ] Share an image → "works with text only" alert
- [ ] Copy from extension → text is on pasteboard

## Unsupported device (iPhone 14)
- [ ] Install → UnsupportedDeviceView shown with "deviceNotEligible" copy
- [ ] App doesn't crash; Recent tab not shown

## Apple Intelligence off (settings)
- [ ] Launch → UnsupportedDeviceView with "Open Settings" link
- [ ] Deep link → opens Settings app

## Offline
- [ ] Airplane mode on → full Enhance flow still works (proves on-device only)

## iPad Air M1
- [ ] Layout is readable in portrait and landscape
- [ ] Split view with another app → TalkNative adapts
