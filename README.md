# omarchy-grok-bot

Omarchy Quattro plugin that keeps Grok Bot running and puts a blob on the bar.

Plugin id: `limehawk.grok-bot`

Install:

```
mkdir -p ~/.config/omarchy/plugins/limehawk.grok-bot
cp -a BarWidget.qml Service.qml manifest.json assets ~/.config/omarchy/plugins/limehawk.grok-bot/
omarchy plugin enable limehawk.grok-bot
```

Click the bar blob to show or hide the window. Closing the window still quits Electron; the service starts it again. New windows open on `special:grokbot` via a Hyprland window rule.
