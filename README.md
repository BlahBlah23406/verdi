# Verdi 🌱

I'm building Verdi: an app to help people understand their carbon footprint and make lower-emission choices.

Right now, I'm working on the Flutter app and its first carbon-estimation algorithm. The prototype includes an activity journal, a monthly emissions breakdown, local saving, and a travel comparison with a rewards preview.

This is early development. The US pilot uses published EPA factors for commuting and electricity; rewards are a demo, and banking, automatic tracking, real offsets, and payments are planned.

## Run locally

```sh
flutter pub get
flutter run -d chrome
```

The project also includes Android and iOS runners. Use `flutter devices` to select a configured device.

```sh
flutter analyze
flutter test
```

See [the build roadmap](docs/ROADMAP.md) and [algorithm notes](docs/ALGORITHM.md).
