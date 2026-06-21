# OmniCC — WotLK 3.3.5a backport :clock1:

A backport of **OmniCC 11.2.8** to the World of Warcraft *Wrath of the Lich King*
**3.3.5a** client (interface `30300`).

> **Credits**
> OmniCC is created and maintained by **Jason Greer (Tuller)** and
> **João Cardoso (Jaliborc)**.
> Original project: <https://github.com/tullamods/OmniCC>
>
> This 3.3.5a backport was made by **Rikard Jedborg**
> (<https://github.com/JedborgWoW>). All original credit for OmniCC goes to its
> authors — this repository only adapts their work to run on the 3.3.5a client.

## What is OmniCC?

OmniCC is a World of Warcraft addon that adds text to items, spells and abilities
that are on cooldown to indicate when they will be ready to use. In other words:
it turns all the standard analogue cooldowns into digital ones.

Anything should work with OmniCC, from the action bars to the inventory, from the
standard interface to your favorite addon.

## Installation

1. Download / clone this repository.
2. Copy the **`OmniCC`** and **`OmniCC_Config`** folders into
   `World of Warcraft\Interface\AddOns\`.
3. Restart the game (or reload the UI) and make sure both addons are enabled on
   the character selection screen.

## Usage

| Command | Action |
| --- | --- |
| `/omnicc` or `/occ` | Open the configuration window |
| `/omnicc config` | Open the configuration window |
| `/omnicc version` | Print the installed version |

`OmniCC_Config` is load-on-demand — it only loads when you open the options
window, so it costs nothing while playing.

## What changed for 3.3.5a

The original 11.2.8 source targets modern clients. The backport keeps the same
architecture and behaviour but adapts the parts that don't exist on 3.3.5a:

* A new `OmniCC/compat.lua` shims missing APIs (`C_Timer.After`, `GetTickTime`,
  `Round`, `C_AddOns`, `C_UI.Reload`, `securecallfunction`,
  `Texture:SetColorTexture`, and the newer `Cooldown` widget methods).
* The cooldown tracker drives off `Cooldown:SetCooldown` (the only cooldown entry
  point on 3.3.5a). Charge / loss-of-control cooldowns, "Midnight" secret values
  and the Blizzard countdown-text toggle were removed — none exist on this
  client. Finish effects are scheduled via a timer since there is no
  `OnCooldownDone` script.
* `EventUtil` / `EventRegistry` bootstrapping was replaced with a classic event
  frame.
* Finish-effect animations use the 3.3.5a animation API (`Alpha:SetChange`,
  multiplicative `Scale`).
* The config preview window was rebuilt and the `BackdropTemplate` usages were
  removed from the bundled Ace3 libraries (3.3.5a frames have `SetBackdrop`
  natively).

See [OmniCC/CHANGELOG.md](OmniCC/CHANGELOG.md) for the full change list.

## License

OmniCC is released under the MIT License.
Copyright (c) 2010-2025 Jason Greer and João Cardoso.

The original license is preserved unchanged in [LICENSE](LICENSE) and
[OmniCC/LICENSE.txt](OmniCC/LICENSE.txt).
