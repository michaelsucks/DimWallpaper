# Dim Wallpaper

An [Omarchy](https://omarchy.org/) bar widget that dims your wallpaper behind your windows with one click, so the app on screen takes center stage.

![Dim Wallpaper](preview.png)

## Features

- One click to dim, one click to bring the wallpaper back
- Smooth theater-style fade: the wallpaper glides into the dark, with a soft vignette that pulls your eye to the center
- Only the wallpaper dims. Your windows, bar, and notifications stay at full brightness
- Every monitor dims together
- Click-through: the dim layer never blocks the mouse
- Respects `omarchy toggle animations`: with animations off, it switches instantly

## Install

```bash
omarchy plugin add https://github.com/michaelsucks/DimWallpaper --enable
```

## Remove

```bash
omarchy plugin remove io.github.michaelsucks.dim-wallpaper
```

This takes the widget off the bar and deletes the plugin folder. The plugin doesn't change any of your files or settings.

## Usage

Click the drama-masks icon in the bar to toggle. The icon lights up while the wallpaper is dimmed.

### Keybinding / scripting

While the widget is on the bar, it exposes an IPC target, so you can bind it to a key in `~/.config/hypr/bindings.lua`:

```bash
omarchy-shell io.github.michaelsucks.dim-wallpaper toggle
omarchy-shell io.github.michaelsucks.dim-wallpaper enable
omarchy-shell io.github.michaelsucks.dim-wallpaper disable
```

## How it works

The plugin places one full-screen, transparent layer on each monitor, on the Wayland layer between the wallpaper and your windows. Toggling it fades that layer's opacity, so only the wallpaper gets darker. The layer is always present but invisible when off, which keeps the fade smooth from the very first frame.

## License

MIT
