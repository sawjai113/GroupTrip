# Wanderaid Branding Assets

This folder stores source visual assets for Wanderaid so they are easy to find, reuse, and version alongside the app.

## Current files

- `Wanderaid Icon v0.1.png` — earlier icon iteration, RGB source.
- `Wanderaid Icon v0.2.png` — earlier icon iteration, RGB source.
- `Wanderaid Icon v0.3.png` — current app icon source, RGB square source.
- `Wanderaid Icon v0.3 Transparent.png` — current transparent in-app logo source, RGBA square source.

## How these map into the app

Compiled Xcode assets live under:

- `GroupTripApp/Assets.xcassets/AppIcon.appiconset/`
- `GroupTripApp/Assets.xcassets/WanderaidLogoTransparent.imageset/`

Use this `DesignAssets/Branding` folder for original/source artwork. Regenerate the Xcode-ready renditions from here when updating the icon or in-app logo.

Current generated app assets:

```sh
sips -z 1024 1024 "DesignAssets/Branding/Wanderaid Icon v0.3.png" \
  --out "GroupTripApp/Assets.xcassets/AppIcon.appiconset/WanderaidIcon-1024.png"

sips -z 1024 1024 "DesignAssets/Branding/Wanderaid Icon v0.3 Transparent.png" \
  --out "GroupTripApp/Assets.xcassets/WanderaidLogoTransparent.imageset/WanderaidLogoTransparent-1024.png"
```

After regenerating, verify with:

```sh
python3 -m json.tool GroupTripApp/Assets.xcassets/Contents.json >/dev/null
python3 -m json.tool GroupTripApp/Assets.xcassets/AppIcon.appiconset/Contents.json >/dev/null
python3 -m json.tool GroupTripApp/Assets.xcassets/WanderaidLogoTransparent.imageset/Contents.json >/dev/null
xcodebuild -project "GroupTripApp.xcodeproj" -scheme GroupTripApp -destination "generic/platform=iOS" CODE_SIGNING_ALLOWED=NO build
```
