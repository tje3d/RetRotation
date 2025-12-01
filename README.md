# RetRotation (WotLK 3.3.5a)

**RetRotation** is a lightweight, standalone addon for **World of Warcraft: Wrath of the Lich King (3.3.5a)**. It provides a dynamic priority queue for Retribution Paladins, calculating the optimal next spell to cast based on cooldowns, current buffs, and target health.

This addon is designed to replicate the functionality of complex "Clash" or "Faceroll" WeakAuras, but with significantly better performance and zero external dependencies.

## Features

*   **Smart Priority System:** Uses the standard 3.3.5a theorycrafting priority list (Clash system).
*   **Context Aware:**
    *   **Single Target:** Default rotation.
    *   **AoE Mode:** Automatically switches priority when **Seal of Command** is active.
    *   **Execute Phase:** Automatically prioritizes **Hammer of Wrath** when the target is below 20% HP.
    *   **Undead/Demon:** Adjusts priority for Exorcism/Holy Wrath against specific creature types.
*   **Spec Detection:** Automatically hides the frame if you switch to Holy or Protection talents.
*   **Dual Spec Support:** Instantly updates when swapping between Dual Specs.
*   **Visual Cues:**
    *   **Glow:** The optimal spell (leftmost) glows when ready.
    *   **OOM Indicator:** Icons turn blueish if you lack the mana to cast them.
    *   **Cooldowns:** Displays the native cooldown spiral on icons.
*   **Performance:** Highly optimized state-caching prevents UI flickering and reduces CPU usage compared to WeakAuras.

## Installation

1.  Download the files or create them manually.
2.  Navigate to your WoW installation folder:
    `\World of Warcraft\Interface\AddOns\`
3.  Create a folder named **`RetRotation`**.
4.  Ensure the folder contains these two files:
    *   `RetRotation.toc`
    *   `RetRotation.lua`
5.  Launch the game. The addon will appear automatically when you log in as a Retribution Paladin.

## Usage

*   **Positioning:** The frame is unlocked by default. **Left-click and drag** the background area of the icons to move it to your desired location.
*   **Reading the Queue:**
    *   The **Leftmost Icon** (largest/brightest) is the spell you should cast *next*.
    *   The icons to the right show upcoming spells in the queue.
    *   If the first icon is glowing, the spell is ready to cast immediately.

## The Rotation Logic

The addon uses the following priority logic (Clash system), sorted by cooldown readiness:

**Single Target:**
1.  Hammer of Wrath (if < 20% HP)
2.  Judgement
3.  Divine Storm
4.  Crusader Strike
5.  Consecration
6.  Exorcism
7.  Holy Wrath

**AoE Mode (Active when Seal of Command is up):**
1.  Hammer of Wrath (if < 20% HP)
2.  Judgement
3.  Divine Storm
4.  Consecration
5.  Crusader Strike
6.  Holy Wrath
7.  Exorcism

## Configuration

There is no in-game GUI menu to keep the addon lightweight. However, you can easily configure the visuals by opening `RetRotation.lua` in any text editor (like Notepad) and changing the values at the very top:

```lua
-- Configuration
local MAX_ICONS = 5          -- Number of spells to predict in the future
local ICON_SIZE = 40         -- Pixel size of the icons
local SPACING = 5            -- Space between icons
local GLOW_NEXT = true       -- Set to false to disable the glowing border
local SCALE = 1.0            -- Scale of the entire frame (e.g., 0.8 for smaller, 1.2 for larger)
```

*Save the file and type `/reload` in-game to see changes.*

## Troubleshooting

**Q: The frame is not showing up.**
*   Are you a Paladin?
*   Do you have more talent points spent in the **Retribution** tree than in Holy or Prot?
*   Are you alive and not in a vehicle?
*   *Note: If you are low level and have 0 talent points spent, the addon may not show.*

**Q: The icons are blinking/flickering.**
*   Update to the latest version provided. The code includes state-caching to prevent redraws unless the spell state actually changes.

**Q: It's not switching to AoE rotation.**
*   Ensure you have **Seal of Command** active. The addon uses this specific buff to trigger AoE logic.

**Q: I get a "Dependency Missing" error.**
*   This is a standalone addon. It does **not** require WeakAuras, Ace3, or any other libraries. Ensure the `.toc` file is named exactly `RetRotation.toc`.

## License

This project is open-source. Feel free to modify and distribute it for the WotLK community.