# App Store listing

Copy and answers for App Store Connect. Character limits are Apple's.

## Name (30)

TalkNative

## Subtitle (30)

Sound native. Stay private.

## Promotional text (170)

Three native-sounding rewrites of any message, generated on your iPhone with Apple Intelligence. No account, no tracking, nothing leaves your phone.

## Description (4000)

TalkNative rewrites what you write so it reads like a native English speaker wrote it. Paste a message, tap Enhance, and get three rewrites side by side in different tones: professional, friendly, concise, and more. Pick the one that fits, copy it, and send.

It fixes what non-native writers get wrong most often: articles, prepositions, word order, idioms, and phrasing that is correct but stiff. Your meaning stays exactly as you wrote it. Nothing is added, nothing is dropped.

PRIVATE BY DESIGN
On iPhones with Apple Intelligence, every rewrite is generated on the device by Apple's on-device model. Your text never leaves your phone. There is no account, no analytics, and no telemetry.

WORKS WHERE YOU WRITE
• Share sheet: select text in any app, share it to TalkNative, and copy the rewrite back.
• Keyboard: enable the TalkNative keyboard and rewrite text in place inside Messages, Mail, Slack, or any text field, with one-tap undo.
• App: paste, enhance, compare, copy.

TONES THAT MATCH THE MOMENT
Eight built-in presets, from casual chat to formal business email. Turn presets on and off, or write your own with a short instruction like "warm, but keep it short."

RECENTS
Your last 50 enhancements are kept on your phone so you can reuse them. Clear them any time.

CLOUD OPTION FOR OLDER IPHONES
On iPhones that do not support Apple Intelligence, TalkNative can use a cloud model instead. It is off by default and asks for your consent first. When enabled, only the text you choose to enhance is sent over HTTPS, and it is not stored.

REQUIREMENTS
iOS 26 or later. On-device rewriting needs Apple Intelligence (iPhone 15 Pro and later). Older iPhones on iOS 26 can use the cloud option.

## Keywords (100)

english,grammar,rewrite,writing,tone,proofread,esl,keyboard,apple intelligence,polish,email,native

## What's new (v1.0)

First release.

## Category

Primary: Productivity. Secondary: Education.

## URLs

- Support: https://github.com/chiliec/TalkNative
- Privacy policy: https://github.com/chiliec/TalkNative/blob/main/PRIVACY.md
- Marketing: none

## Age rating

4+. No objectionable content. The app generates text from user input only.

## App privacy (nutrition labels)

Does the app collect data: **Yes**, one type.

| Data type | Collected | Linked to user | Used for tracking | Purpose |
|---|---|---|---|---|
| User Content > Other User Content | Yes, only in cloud mode | No | No | App Functionality |

Notes for the form:
- The text a user chooses to enhance is sent to the TalkNative gateway only when cloud mode is on, and only on devices without Apple Intelligence. It is processed transiently and not stored.
- No identifiers, contact info, usage data, or diagnostics are collected. No third-party SDKs.
- Matches `PrivacyInfo.xcprivacy` in the app and both extensions.

## Export compliance

Uses only standard HTTPS. `ITSAppUsesNonExemptEncryption` is set to NO in every bundle, so App Store Connect should not prompt.

## App Review notes

No login. No demo account needed.

On-device mode requires Apple Intelligence. On a review device without it, the app shows a consent screen; accept it, or turn on "Cloud mode" in Settings, and enhancement works over the network. The review device must be on iOS 26.

To test the keyboard: Settings > General > Keyboard > Keyboards > Add New Keyboard > TalkNative. Full Access is optional; without it the keyboard uses built-in presets only. In any text field, switch to the TalkNative keyboard with the globe key, tap a preset, and the selected text (or the text before the cursor) is rewritten in place. Undo restores the original.

To test the Share extension: select text in Notes, tap Share, choose TalkNative.

## Screenshots

6.9-inch (iPhone 17 Pro Max) and 6.7-inch sets are required. Suggested shots, in order:

1. Enhance tab with three streamed variants for a short, obviously non-native message.
2. Keyboard panel open in Messages with the rewrite applied and the undo strip visible.
3. Share sheet from Notes landing in the result sheet.
4. Presets screen showing built-ins and one custom preset.
5. Privacy screen.

Generate with the stub provider on the simulator: launch with `-useStubEnhancer` and `TALKNATIVE_PREFILL_INPUT` set to the sample text.
