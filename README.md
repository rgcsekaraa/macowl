<p align="center">
  <img src="docs/icon.png" alt="macowl icon" width="160" height="160">
</p>

<h1 align="center">macowl</h1>

<p align="center">A tiny owl in your menu bar that keeps your Mac awake.</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-blue" alt="Platform macOS 13+">
  <img src="https://img.shields.io/badge/made%20with-Swift-orange" alt="Made with Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

A tiny menu bar app that keeps your Mac awake. It sits quietly in the menu bar
as a small owl. When the owl is awake (eyes open), your Mac will not go to
sleep. When the owl is sleeping (eyes closed), everything is normal.

That is the whole idea. No settings window, no Dock icon, nothing heavy. Just
one owl in the menu bar.

## Why I made this

Many times my Mac goes to sleep when I do not want it to. For example, a long
download is running, or a build is going on, or I just want the music to keep
playing. The usual trick is the `caffeinate` command in the terminal, but I
wanted something simple that I can click from the menu bar.

So macowl does exactly that, and it does it the clean way. It uses the proper
macOS power assertions through IOKit. It does not run any extra `caffeinate`
process in the background.

## What it can do

macowl has four simple states. You pick one from the menu.

| State | What happens |
|-------|--------------|
| **Off** | Normal. Your Mac sleeps like usual. The owl is sleeping. |
| **On - System** | The Mac will not sleep, but the screen can still dim and switch off. |
| **On - System + Display** | The whole Mac and the screen both stay awake. |
| **On - Even with Lid Closed** | The Mac keeps running even after you close the lid. |

The last one is the special one. Please read the
[lid closed section](#keeping-the-mac-awake-with-the-lid-closed) below before
using it, because it asks for your admin password and it changes a system
setting.

There is also a **Start at Login** option, so macowl can open by itself every
time you switch on your Mac.

## Installing

### The easy way (DMG)

1. Go to the [Releases](../../releases) page.
2. Download the latest `macowl-x.y.z.dmg`.
3. Open the DMG and drag **macowl** into your **Applications** folder.
4. Open it. Look for the owl in your menu bar at the top right.

Because the app is signed only with an ad-hoc signature (not a paid Apple
developer certificate), macOS may show a warning the first time. If that
happens, right click the app and choose **Open**, then click **Open** again.
You only need to do this once.

### Building it yourself

You need a Mac with the Xcode command line tools. If you can run `swiftc`, you
are ready.

```sh
git clone https://github.com/rgcsekaraa/macowl.git
cd macowl
./build.sh
```

`build.sh` compiles the app, makes the icon, installs it into `/Applications`
and opens it. That is all.

### Making a DMG to share

If you want to make your own DMG (for example to give it to a friend), run:

```sh
./build-dmg.sh
```

This builds the app into the `dist` folder and creates `dist/macowl-1.0.0.dmg`.
It does not touch `/Applications` or your running copy.

## Uninstalling

macowl is just one app, so removing it is easy.

1. Click the owl and choose **Quit macowl**.
2. If you turned on Start at Login, turn it off first from the menu, or remove
   macowl from **System Settings > General > Login Items**.
3. Move **macowl** from your **Applications** folder to the Trash.

If you ever used the lid closed state and want to be fully sure your sleep
setting is back to normal, run this once:

```sh
sudo pmset -a disablesleep 0
```

## Using it

Click the owl in the menu bar. You will see a small menu:

- A line at the top showing the current status.
- The four states you can pick.
- **Start at Login** to open macowl automatically.
- **Quit macowl** to close it.

Pick a state and you are done. The owl in the menu bar will open its eyes when
a keep-awake state is on, and close them when it is off. You can also hover on
the owl to see the current status in a tooltip.

## Keeping the Mac awake with the lid closed

This one is different from the other states, so please read this part.

When you close the lid of a MacBook, macOS goes to sleep. There is no power
assertion that can stop this. The only reliable way to keep the Mac running
with the lid shut is the system setting `pmset disablesleep`. macowl uses this
setting for the **On - Even with Lid Closed** state.

A few important points:

1. **It asks for your admin password.** Turning this state on and off changes a
   system setting, so macOS asks for your password each time. This is normal and
   there is no way around it without installing a background helper tool, which
   macowl does not do on purpose, to keep things simple and safe.

2. **It stops all sleep, not only lid sleep.** While this state is on, the Mac
   will not sleep at all, even when the lid is open and idle. That is the nature
   of the system setting.

3. **The screen will be off when the lid is closed.** This is obvious, but worth
   saying. The lid is shut, so the screen is off. But the CPU, the network, your
   downloads and everything else keep running.

4. **macowl cleans up after itself.** When you turn this state off, or quit
   macowl, the setting is put back to normal. If macowl is force quit or crashes
   while this state is on, the setting can stay on. To handle this, macowl keeps
   a small marker file and checks it the next time it opens. If it finds that the
   Mac was left awake by mistake, it will ask you whether to keep it awake or to
   restore normal sleep. So your Mac will not get stuck awake forever.

If you ever want to reset this setting by hand, you can run this in the
terminal:

```sh
sudo pmset -a disablesleep 0
```

## Questions people ask

**Does this drain my battery?**
Yes, keeping the Mac awake uses more power than letting it sleep, especially the
lid closed state. Use it when you need it and turn it off after.

**Will it stop my screen saver also?**
The display states stop the screen from sleeping, so the screen saver may not
start. The plain System state does not touch the display.

**Does it run any background process like caffeinate?**
No. macowl uses IOKit power assertions directly. The only system command it runs
is `pmset`, and only for the lid closed state.

**Why does it want my password?**
Only for the lid closed state, because that changes a system setting. The other
states do not need any password.

## How it works, in short

For the curious, here is the simple version:

- For the System and Display states, macowl creates an IOKit power assertion
  (`kIOPMAssertPreventUserIdleSystemSleep` or
  `kIOPMAssertPreventUserIdleDisplaySleep`). This is the clean, official way to
  ask macOS to stay awake. macowl holds only one assertion at a time.
- For the lid closed state, there is no assertion that works, so macowl flips
  the `pmset disablesleep` system setting. To stay safe, it remembers this with
  a marker file and checks it on the next launch.

The whole app is a single Swift file, `main.swift`, and the icon is drawn in
code in `makeicon.swift`. No frameworks, no dependencies.

## Contributing

Pull requests and ideas are welcome. Please see
[CONTRIBUTING.md](CONTRIBUTING.md) for how to build, test and send changes.

Please also read the [Code of Conduct](CODE_OF_CONDUCT.md) and the
[Changelog](CHANGELOG.md).

## Thanks

Thank you for using macowl. It is a small app made with care. If it helps you,
a star on the repo would make my day.

## License

macowl is open source under the [MIT license](LICENSE). You are free to use it,
change it, and share it. If you make something nice out of it, that is
wonderful.
