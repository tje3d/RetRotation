# ⚔️ RetRotation (WotLK 3.3.5a)

![RetRotation Preview](62fa8889c843c08b0ba865d8.gif)

**RetRotation** is a lightweight, standalone addon for **World of Warcraft: Wrath of the Lich King (3.3.5a)**. It supercharges your Retribution Paladin gameplay by calculating the optimal spell to cast next based on cooldowns, buffs, and target health.

Think of it as a high-performance replacement for "Clash" or "Faceroll" WeakAuras, but with **zero dependencies** and optimized code! 🚀

---

## ✨ Features

*   🧠 **Smart Priority System:** Implements the standard 3.3.5a theorycrafting priority list (Clash system).
*   🔄 **Context Aware:**
    *   🎯 **Single Target:** Standard rotation optimization.
    *   💥 **AoE Mode:** Automatically switches priority when **Seal of Command** is active.
    *   ☠️ **Execute Phase:** Prioritizes **Hammer of Wrath** when target is < 20% HP.
    *   🧟 **Undead/Demon:** Adjusts Exorcism/Holy Wrath priority for specific enemy types.
*   🛡️ **Spec Detection:** Auto-hides if you switch to Holy or Protection.
*   ⚡ **Dual Spec Support:** Updates instantly when swapping specs.
*   👀 **Visual Cues:**
    *   **Glow:** The optimal spell (leftmost) glows when ready.
    *   **OOM Indicator:** Icons turn blueish if you lack mana.
    *   **Cooldowns:** Native cooldown spirals.
*   🚀 **High Performance:** State-caching prevents UI flickering and keeps CPU usage low.

---

## 📦 Installation

1.  Download the files.
2.  Navigate to your WoW AddOns folder:
    `\World of Warcraft\Interface\AddOns\`
3.  Create a folder named **`RetRotation`**.
4.  Place the following files inside:
    *   `RetRotation.toc`
    *   `RetRotation.lua`
    *   `62fa8889c843c08b0ba865d8.gif` (Optional, for README)
5.  Launch WoW! The addon appears automatically when you log in as a Retribution Paladin.

---

## 🎮 Usage

*   **Move It:** The frame is unlocked by default. **Left-click and drag** the background to position it.
*   **Read It:**
    *   **Leftmost Icon:** The spell you should cast **NEXT**.
    *   **Right Icons:** Upcoming spells.
    *   **Glowing Border:** Spell is ready to cast immediately!

---

## ⚔️ The Rotation Logic

We use the proven **Clash System** priority list:

### 🎯 Single Target
1.  🔨 **Hammer of Wrath** (if < 20% HP)
2.  ⚖️ **Judgement**
3.  🌪️ **Divine Storm**
4.  ⚔️ **Crusader Strike**
5.  🔥 **Consecration**
6.  👻 **Exorcism**
7.  🙏 **Holy Wrath**

### 💥 AoE Mode
*(Active when Seal of Command is up)*
1.  🔨 **Hammer of Wrath** (if < 20% HP)
2.  ⚖️ **Judgement**
3.  🌪️ **Divine Storm**
4.  🔥 **Consecration**
5.  ⚔️ **Crusader Strike**
6.  🙏 **Holy Wrath**
7.  👻 **Exorcism**

---

## ⚙️ Configuration

No bloatware GUI here! To configure visuals, simply edit the top of `RetRotation.lua` in any text editor (like Notepad):

```lua
-- Configuration
local MAX_ICONS = 5          -- Number of spells to predict
local ICON_SIZE = 40         -- Pixel size of icons
local SPACING = 5            -- Space between icons
local GLOW_NEXT = true       -- Toggle glowing border
local SCALE = 1.0            -- Frame scale (e.g., 1.2 for bigger)
```

*Save and type `/reload` in-game to apply changes.*

---

## ❓ Troubleshooting

**Q: The frame isn't showing up!**
*   Are you a Paladin?
*   Are you Retribution spec? (More points in Ret tree than others)
*   Are you alive and not in a vehicle?

**Q: Icons are flickering?**
*   Update to the latest version. Our state-caching fixes this!

**Q: AoE rotation isn't working?**
*   Make sure **Seal of Command** is active.

**Q: "Dependency Missing" error?**
*   This addon is standalone! You don't need WeakAuras, Ace3, or any other libraries. Ensure the folder is named `RetRotation`.

---

## 📜 License

Open-source for the WotLK community. Feel free to modify and share! ❤️
