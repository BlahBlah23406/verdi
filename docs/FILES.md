# File overview

Provides a short purpose statement for every tracked project file, including non-commentable assets.

Code and commentable configuration files also contain a short overview. JSON, CSV, and image formats keep their required structure; their descriptions live here. Generated files may lose inline comments when tools regenerate them.

| File | Purpose |
| --- | --- |
| [.gitignore](../.gitignore) | Excludes local tools, generated build output, and machine-specific files from Git. |
| [.metadata](../.metadata) | Records Flutter project and platform migration metadata. |
| [README.md](../README.md) | Introduces Verdi, its automatic tracking algorithm, and the current development focus. |
| [analysis_options.yaml](../analysis_options.yaml) | Configures Dart static analysis and the Flutter lint rules. |
| [android/.gitignore](../android/.gitignore) | Excludes generated files and local settings for the android platform. |
| [android/app/build.gradle.kts](../android/app/build.gradle.kts) | Configures Android app compilation, identifiers, build types, and Flutter integration. |
| [android/app/src/debug/AndroidManifest.xml](../android/app/src/debug/AndroidManifest.xml) | Enables network access used by Flutter development tools in debug builds. |
| [android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) | Declares the Android application, main activity, and foreground location permissions. |
| [android/app/src/main/kotlin/com/verdi/verdi/MainActivity.kt](../android/app/src/main/kotlin/com/verdi/verdi/MainActivity.kt) | Bridges Android foreground GPS and permission events into the Flutter location stream. |
| [android/app/src/main/res/drawable-v21/launch_background.xml](../android/app/src/main/res/drawable-v21/launch_background.xml) | Defines the Android launch background displayed while Flutter starts. |
| [android/app/src/main/res/drawable/launch_background.xml](../android/app/src/main/res/drawable/launch_background.xml) | Defines the Android launch background displayed while Flutter starts. |
| [android/app/src/main/res/mipmap-hdpi/ic_launcher.png](../android/app/src/main/res/mipmap-hdpi/ic_launcher.png) | Provides the Android launcher icon for this resource density. |
| [android/app/src/main/res/mipmap-mdpi/ic_launcher.png](../android/app/src/main/res/mipmap-mdpi/ic_launcher.png) | Provides the Android launcher icon for this resource density. |
| [android/app/src/main/res/mipmap-xhdpi/ic_launcher.png](../android/app/src/main/res/mipmap-xhdpi/ic_launcher.png) | Provides the Android launcher icon for this resource density. |
| [android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png](../android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png) | Provides the Android launcher icon for this resource density. |
| [android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png](../android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png) | Provides the Android launcher icon for this resource density. |
| [android/app/src/main/res/values-night/styles.xml](../android/app/src/main/res/values-night/styles.xml) | Defines Android launch and app window styles for dark mode. |
| [android/app/src/main/res/values/styles.xml](../android/app/src/main/res/values/styles.xml) | Defines Android launch and app window styles for light mode. |
| [android/app/src/profile/AndroidManifest.xml](../android/app/src/profile/AndroidManifest.xml) | Enables network access used by Flutter tools in profile builds. |
| [android/build.gradle.kts](../android/build.gradle.kts) | Configures shared Android build repositories, output locations, and cleanup. |
| [android/gradle.properties](../android/gradle.properties) | Sets Gradle runtime and Android build options. |
| [android/gradle/wrapper/gradle-wrapper.properties](../android/gradle/wrapper/gradle-wrapper.properties) | Pins the Gradle distribution used by the Android wrapper. |
| [android/settings.gradle.kts](../android/settings.gradle.kts) | Locates the Flutter SDK and declares Android build plugins and modules. |
| [docs/ALGORITHM.md](../docs/ALGORITHM.md) | Documents emission formulas, factor sources, calculation boundaries, and remaining validation. |
| [docs/AUTOMATIC_TRACKING.md](../docs/AUTOMATIC_TRACKING.md) | Explains automatic ingestion, consent, reconciliation, and required device acceptance checks. |
| [docs/FILES.md](../docs/FILES.md) | Provides a short purpose statement for every tracked project file, including non-commentable assets. |
| [docs/ROADMAP.md](../docs/ROADMAP.md) | Maps the business plan to implemented foundations and future product milestones. |
| [docs/VALIDATION.md](../docs/VALIDATION.md) | Records completed checks, environment limitations, and outstanding validation. |
| [examples/utility_readings.csv](../examples/utility_readings.csv) | Provides two example daily electricity readings in the normalized import schema. |
| [ios/.gitignore](../ios/.gitignore) | Excludes generated files and local settings for the ios platform. |
| [ios/Flutter/AppFrameworkInfo.plist](../ios/Flutter/AppFrameworkInfo.plist) | Defines metadata and platform requirements for the embedded Flutter app framework. |
| [ios/Flutter/Debug.xcconfig](../ios/Flutter/Debug.xcconfig) | Includes generated Flutter build settings for debug configurations. |
| [ios/Flutter/Release.xcconfig](../ios/Flutter/Release.xcconfig) | Includes generated Flutter build settings for release configurations. |
| [ios/Runner.xcodeproj/project.pbxproj](../ios/Runner.xcodeproj/project.pbxproj) | Defines Xcode targets, file references, build phases, and app build settings. |
| [ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata](../ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata) | Defines the project references included in this Xcode workspace. |
| [ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist](../ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist) | Records shared Xcode workspace compatibility checks. |
| [ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings](../ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings) | Configures shared Xcode workspace build and preview behavior. |
| [ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme](../ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme) | Defines Xcode build, run, test, profile, and archive actions for the app. |
| [ios/Runner.xcworkspace/contents.xcworkspacedata](../ios/Runner.xcworkspace/contents.xcworkspacedata) | Defines the project references included in this Xcode workspace. |
| [ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist](../ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist) | Records shared Xcode workspace compatibility checks. |
| [ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings](../ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings) | Configures shared Xcode workspace build and preview behavior. |
| [ios/Runner/AppDelegate.swift](../ios/Runner/AppDelegate.swift) | Registers Flutter plugins and streams foreground iOS location updates with permission handling. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json) | Maps image files to the sizes and device roles in this Xcode asset set. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png](../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png) | Provides an iOS app icon at the size and scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json](../ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json) | Maps image files to the sizes and device roles in this Xcode asset set. |
| [ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png](../ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png) | Provides an iOS launch-image bitmap at the scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png](../ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png) | Provides an iOS launch-image bitmap at the scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png](../ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png) | Provides an iOS launch-image bitmap at the scale indicated by its filename. |
| [ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md](../ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md) | Describes the generated launch-image assets and how they are replaced. |
| [ios/Runner/Base.lproj/LaunchScreen.storyboard](../ios/Runner/Base.lproj/LaunchScreen.storyboard) | Defines the native iOS launch screen shown before Flutter renders. |
| [ios/Runner/Base.lproj/Main.storyboard](../ios/Runner/Base.lproj/Main.storyboard) | Creates the initial Flutter view controller for the iOS app. |
| [ios/Runner/Info.plist](../ios/Runner/Info.plist) | Declares iOS app metadata, scenes, supported orientations, and the location permission explanation. |
| [ios/Runner/Runner-Bridging-Header.h](../ios/Runner/Runner-Bridging-Header.h) | Exposes the generated Objective-C plugin registrant to Swift. |
| [ios/Runner/SceneDelegate.swift](../ios/Runner/SceneDelegate.swift) | Connects the iOS scene lifecycle to Flutter. |
| [ios/RunnerTests/RunnerTests.swift](../ios/RunnerTests/RunnerTests.swift) | Provides the generated iOS runner test scaffold. |
| [lib/data/activity_store.dart](../lib/data/activity_store.dart) | Loads and saves confirmed activities in device-local preferences. |
| [lib/data/automation_store.dart](../lib/data/automation_store.dart) | Persists pending activity candidates and discarded record identities. |
| [lib/domain/automation.dart](../lib/domain/automation.dart) | Segments location samples into trips, parses utility readings, and checks activity overlap. |
| [lib/domain/carbon.dart](../lib/domain/carbon.dart) | Defines activity records and calculates period totals, category breakdowns, and travel comparisons. |
| [lib/domain/emission_factors.dart](../lib/domain/emission_factors.dart) | Defines the versioned EPA emission factors, unit conversions, and source metadata. |
| [lib/features/automation_screen.dart](../lib/features/automation_screen.dart) | Presents tracking consent, utility imports, and the candidate review queue. |
| [lib/main.dart](../lib/main.dart) | Starts the Flutter app and builds the overview, journal, comparison, and tracking navigation. |
| [lib/services/phone_tracking.dart](../lib/services/phone_tracking.dart) | Converts native location events into typed Dart location samples. |
| [pubspec.lock](../pubspec.lock) | Pins resolved dependency versions for reproducible package installation. |
| [pubspec.yaml](../pubspec.yaml) | Declares the Flutter app, SDK constraints, dependencies, and bundled resources. |
| [test/automation_test.dart](../test/automation_test.dart) | Checks automatic ingestion, review-queue persistence, and confirmation into the activity journal. |
| [test/carbon_test.dart](../test/carbon_test.dart) | Checks emissions calculations, historical factors, reporting periods, and activity persistence. |
| [test/widget_test.dart](../test/widget_test.dart) | Checks the main activity flow and small-screen Flutter layouts. |
| [tool/check_algorithm.dart](../tool/check_algorithm.dart) | Runs standalone calculation checks without the Flutter test runner. |
| [tool/check_automation.dart](../tool/check_automation.dart) | Runs standalone trip-detection, import-validation, and reconciliation checks. |
| [web/favicon.png](../web/favicon.png) | Provides the browser tab icon. |
| [web/icons/Icon-192.png](../web/icons/Icon-192.png) | Provides a web app icon at the size indicated by its filename. |
| [web/icons/Icon-512.png](../web/icons/Icon-512.png) | Provides a web app icon at the size indicated by its filename. |
| [web/icons/Icon-maskable-192.png](../web/icons/Icon-maskable-192.png) | Provides a web app icon with maskable padding at the size indicated by its filename. |
| [web/icons/Icon-maskable-512.png](../web/icons/Icon-maskable-512.png) | Provides a web app icon with maskable padding at the size indicated by its filename. |
| [web/index.html](../web/index.html) | Bootstraps Flutter in the browser and declares page metadata. |
| [web/manifest.json](../web/manifest.json) | Defines the web app name, display behavior, theme, and installable icons. |
