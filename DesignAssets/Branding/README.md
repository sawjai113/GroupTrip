# Wanderaid Branding Assets

This folder stores source visual assets for Wanderaid so they are easy to find, reuse, and version alongside the app.

## Current files

- `Wanderaid Icon v0.01.png` — earlier icon iteration, RGB source.
- `Wanderaid Icon v0.02.png` — earlier icon iteration, RGB source.
- `Wanderaid Icon v0.03.png` — earlier icon iteration, RGB square source.
- `Wanderaid Icon v0.03 Transparent.png` — earlier transparent in-app logo source, RGBA square source.
- `Wanderaid Icon v0.04.png` — earlier app icon source, RGB square source.
- `Wanderaid Icon v0.05 Simple Candidate.png` — simpler generated icon candidate, not used by the app.
- `Wanderaid Icon v0.06 Flat Candidate.svg` — flat editable icon candidate, not used by the app.
- `Wanderaid Icon v0.06 Flat Candidate.png` — rendered preview of the flat editable candidate, not used by the app.
- `Wanderaid Icon v0.07 Wan Shadow Candidate.svg` — flat no-paper-plane candidate with an offset `Wan` wordmark, not used by the app.
- `Wanderaid Icon v0.07 Wan Shadow Candidate.png` — rendered preview of v0.07, not used by the app.
- `Wanderaid Icon v0.08 Minimal Wan Candidate.svg` — simplified flat cup candidate with a calmer offset `Wan` wordmark, not used by the app.
- `Wanderaid Icon v0.08 Minimal Wan Candidate.png` — rendered preview of v0.08, not used by the app.
- `Wanderaid Icon v0.09 v0.05 Reference Candidate.png` — generated candidate based on v0.05 with no paper airplane and an offset `Wan` wordmark, not used by the app.
- `Wanderaid Icon v0.10 Winged Sleeve Candidate.png` — generated v0.09 refinement with the winged sleeve restored, not used by the app.
- `Wanderaid Icon v0.11 Compact Winged Sleeve Candidate.png` — generated v0.10 refinement with smaller wings and more readable `Wan` wordmark, not used by the app.
- `Wanderaid Icon v0.12 v0.05 Cup Winged Candidate.png` — current app icon source, returning closer to the v0.05 cup, straw, and winged sleeve shape.

## How these map into the app

Compiled Xcode assets live under:

- `GroupTripApp/Assets.xcassets/AppIcon.appiconset/`
- `GroupTripApp/Assets.xcassets/WanderaidLogoTransparent.imageset/`

Use this `DesignAssets/Branding` folder for original/source artwork. Regenerate the Xcode-ready renditions from here when updating the icon or in-app logo.

Current generated app assets:

```sh
sips -z 1024 1024 "DesignAssets/Branding/Wanderaid Icon v0.12 v0.05 Cup Winged Candidate.png" \
  --out "GroupTripApp/Assets.xcassets/AppIcon.appiconset/WanderaidIcon-1024.png"

sips -z 1024 1024 "DesignAssets/Branding/Wanderaid Icon v0.12 v0.05 Cup Winged Candidate.png" \
  --out "GroupTripApp/Assets.xcassets/WanderaidLogoTransparent.imageset/WanderaidLogoTransparent-1024.png"
```

After regenerating, verify with:

```sh
python3 -m json.tool GroupTripApp/Assets.xcassets/Contents.json >/dev/null
python3 -m json.tool GroupTripApp/Assets.xcassets/AppIcon.appiconset/Contents.json >/dev/null
python3 -m json.tool GroupTripApp/Assets.xcassets/WanderaidLogoTransparent.imageset/Contents.json >/dev/null
xcodebuild -project "GroupTripApp.xcodeproj" -scheme GroupTripApp -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```
