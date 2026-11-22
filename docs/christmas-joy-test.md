# Christmas joy paid theme

Christmas joy ships in the game update. An unowned copy offers one game per local installation. The player can leave and resume it. Once the game ends, the finished board is saved and the next-piece area opens the Google Play purchase option. An acknowledged purchase moves the theme into the owned section and enables the replay button.

Create and activate a non-consumable one-time product with the ID `christmas_joy` in Play Console for `org.shinegame.tiles`. Set its price and availability there. Tiles displays the formatted price for the offer it passes to checkout. The earlier `christmas_joy_test` product and desktop preview receipt were for the checkout prototype.

To check the purchase end to end, upload an Android App Bundle with an unused version code to a Play test track, set up a license tester, and install through Play. Finish the trial, cancel checkout, then complete it. Restart once, then remove and reinstall the app to verify that Play restores ownership. Trial progress is stored on-device and survives updates. A reinstall without backup can start a new local trial.

For another paid theme, add its artwork manifest and registry profile with a unique `play_product` value. The menu, trial saves, price handling, and replay unlock use that registry entry.
