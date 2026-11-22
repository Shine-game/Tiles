# Christmas joy purchase and delivery test

The Themes page includes a **Coming soon** section. On desktop, **Limited offer — €0.00** opens a local test confirmation. Confirming installs a preview receipt and moves Christmas joy above the divider into the theme library. The preview has no playable artwork.

## Google Play checkout

1. In Play Console for `org.shinegame.tiles`, create and activate the non-consumable one-time product `christmas_joy_test`. Use a valid Play Console price. Google Play sets the price in its checkout sheet.
2. Add your account under **License testing** and use that account on the device. Choose a Play test payment method to test approval or decline without a charge. Membership in a test track alone does not make transactions free.
3. For the Android test build, add the following to `project.godot`. Keep this setting off in public builds. The app also requires a debug export to enable checkout.

   ```ini
   [tiles]

   store/play_billing_test_enabled=true
   ```

4. Export with Gradle, upload the signed debug APK through Play Console Internal app sharing, and install it through the sharing link using the account above. Tap Christmas joy in Themes. Check approval, cancellation, and restoration after reopening. This client-side flow is for testing only. Use server-side Play purchase verification before offering paid artwork publicly.

## Download test

By default, installation writes the bundled preview receipt. To test network delivery, host the following text at a directly accessible HTTPS URL and set `store/christmas_preview_url="https://…"` under `[tiles]` in the test build.

```json
{"product":"christmas_joy_test","version":1,"preview":true}
```

The app checks the exact payload before saving it. The preview appears in the library after installation succeeds. On Android, Google Play ownership is checked again on startup.
