# SwingLab privacy policy — development version 0.1

Effective date: 26 October 2026. This describes the implementation in this repository. Before public distribution, the publisher must add its identity and privacy contact, host this policy at an accessible public URL, and review the final signed binary and App Store disclosures.

SwingLab does not require an account. It stores imported and recorded videos, pose-analysis results, club profiles, manually supplied course references, scorecards, GPS shot records, and preferences in the app's local storage. Videos are analyzed on the iPhone. This version has no cloud upload service, advertising SDK, or analytics SDK.

Camera access is requested when you choose to record. After camera access, SwingLab asks once for microphone access. If you allow it, swing videos include sound, which is analyzed on this iPhone only to time the moment of impact; it is never uploaded. If you decline, recording works without sound. Imported videos may contain their original audio, which is analyzed the same way. The system photo picker gives access to the video you select; SwingLab copies it to app storage and does not request unrestricted access to your photo library.

Location access is requested for foreground course actions. A GPS fix is requested when you tap the location control or need a fresh fix to log a shot. Coordinates, timestamps, and horizontal accuracy are saved when you explicitly record a shot. There is no always-on or background location tracking.

Maps and course search use Apple's MapKit services. Network requests, including a search term and search region when applicable, are handled by Apple under [Apple's privacy policy](https://www.apple.com/legal/privacy/). Maps and search may need internet access. Viewing maps may cause Apple service requests even if you have not granted location permission; a manually placed map coordinate is not a GPS fix.

Records remain until you delete them or remove the app. Individual club, video, and round controls and Settings → Delete all local data remove SwingLab's records and video copies. Full deletion retains language and unit preferences. It does not remove original Photos videos or exported copies. Device backups, their retention, and restoration are controlled by iOS and your backup settings. An operating-system backup may contain app data; this is separate from a SwingLab upload service.

Original-video export uses the system share sheet. You choose the receiving app or destination, which then handles the shared file under its own policies. Spoken feedback uses the system speech synthesizer and an available compatible voice.

You can change camera and location permissions in iPhone Settings. Manual course references and score entry remain available without GPS, and video import remains available without camera access. No assertion of global legal compliance or a completed App Store privacy review is made for this development build.
