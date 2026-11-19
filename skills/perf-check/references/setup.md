# Setup

- adb: install Android platform-tools (`brew install --cask android-platform-tools`, or the
  Android SDK). Check with `adb devices`.
- Device: a physical phone gives real numbers; an emulator's frame times follow the host. Turn on
  USB debugging, accept the host's key, and keep the screen on while plugged in
  (`adb shell svc power stayon usb`, with the user's yes, since it changes a device setting).
- Python: Python 3.9 or newer with `pip3 install --user perfetto`. The package downloads its
  trace processor binary on first use.
- Release build: the app's release variant must be signed with the same key as the installed
  development build, or `install -r` refuses and the user would have to uninstall (and lose the
  signed-in session). Expo's default `android/app/build.gradle` signs release with the debug key.
