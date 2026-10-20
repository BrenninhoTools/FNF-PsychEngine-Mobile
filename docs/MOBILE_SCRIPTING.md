# Mobile Scripting (Lua & HScript)

These functions work in every Lua script. On desktop they are safe to call: they return neutral values (`false`, `0`, `-1`) or use the mouse instead of touches.

In HScript, use the `MobileAPI` class (for example `MobileAPI.vibrate(150)`). `isMobile()` and `vibrate()` are also available directly, and on mobile `TouchInput` and `VirtualPad` are exposed too.

## Device

| Function | Returns | Description |
|---|---|---|
| `isMobile()` | Bool | `true` on Android and iOS |
| `getPlatform()` | String | `android`, `ios`, `windows`, `mac` or `linux` |
| `vibrate(duration = 100)` | | Vibrates the device for `duration` milliseconds |
| `mobileToast(text, long = false)` | | Shows an Android toast message |
| `keepScreenOn(value = true)` | | Stops the screen from turning off |
| `getBatteryLevel()` | Int | Battery percentage, or `-1` if unknown |
| `isCharging()` | Bool | `true` while charging |
| `getStorageType()` | String | `Data`, `Media`, `Obb` or `External` |
| `getStoragePath()` | String | Folder where the game files are |
| `getScreenStyle()` | String | `Original` or `Full` |
| `getWideOffset()` | Float | Extra space on each side in the Full screen style |

## Touch

Positions are in game coordinates.

| Function | Returns | Description |
|---|---|---|
| `touchPressed()` | Bool | Any finger is on the screen |
| `touchJustPressed()` | Bool | A finger touched the screen this frame |
| `touchJustReleased()` | Bool | A finger left the screen this frame |
| `touchTapped()` | Bool | A quick tap happened this frame |
| `getTouchCount()` | Int | How many fingers are on the screen |
| `getTouchX(index = 0)` / `getTouchY(index = 0)` | Float | Position of a finger (or of the last release) |
| `touchOverlaps(object, camera = '')` | Bool | A finger is over the object |
| `touchJustTappedOn(object, camera = '')` | Bool | The object was tapped this frame |
| `swiped(direction)` | Bool | Swiped `up`, `down`, `left` or `right` this frame |

## Hitbox

Lanes are `0` (left), `1` (down), `2` (up) and `3` (right).

| Function | Returns | Description |
|---|---|---|
| `hitboxPressed(lane)` | Bool | The lane is being held |
| `hitboxJustPressed(lane)` | Bool | The lane was pressed this frame |
| `hitboxJustReleased(lane)` | Bool | The lane was released this frame |
| `setHitboxVisible(value)` | | Shows or hides the hitbox (it still works) |
| `setPauseButtonVisible(value)` | | Shows or hides the pause button |
| `getHitboxMode()` | String | `Four Lanes` or `Arrows` |

## Virtual Pad

Add your own buttons on any screen, for example in custom states or minigames.

```lua
function onCreate()
	addVirtualPad(true, 'A B')
end

function onUpdate(elapsed)
	if virtualPadJustPressed('A') then
		playSound('confirmMenu')
	end
	if virtualPadPressed('LEFT') then
		setProperty('boyfriend.x', getProperty('boyfriend.x') - 5)
	end
end
```

| Function | Description |
|---|---|
| `addVirtualPad(dpad = true, actions = '', dispatchKeys = true)` | Adds a D-pad and action buttons. `actions` is a list of keys like `'A B'` or `{'ENTER', 'ESCAPE'}`. With `dispatchKeys`, the buttons also press the real keyboard keys |
| `removeVirtualPad()` | Removes the pad (it is also removed when the state changes) |
| `hasVirtualPad()` | `true` if a pad is on screen |
| `setVirtualPadAlpha(alpha)` | Changes the pad transparency |
| `setVirtualPadVisible(value)` | Shows or hides the pad |
| `virtualPadPressed(key)` | The button is being held (`UP`, `DOWN`, `LEFT`, `RIGHT` or an action key) |
| `virtualPadJustPressed(key)` | The button was pressed this frame |
| `virtualPadJustReleased(key)` | The button was released this frame |
