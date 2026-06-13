<p align="center">
  <img src="docs/icon.png" alt="macowl icon" width="160" height="160">
</p>

<h1 align="center">macowl</h1>

<p align="center">A tiny owl in your menu bar that keeps your Mac awake.</p>

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

## Using it

Click the owl in the menu bar. You will see a small menu:

- A line at the top showing the current status.
- The four states you can pick.
- **Start at Login** to open macowl automatically.
- **Quit macowl** to close it.

Pick a state and you are done. The owl in the menu bar will open its eyes when
a keep-awake state is on, and close them when it is off. You can also hover on
the owl to see the current status in a tooltip.

## License

macowl is open source under the [MIT license](LICENSE). You are free to use it,
change it, and share it. If you make something nice out of it, that is
wonderful.
