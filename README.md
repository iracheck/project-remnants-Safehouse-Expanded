# Project Remnants: Safehouse Expanded
## Unofficial Submod developed by iGalaxied

**Safehouse Expanded** is a passion project aiming to make safehouse management in Project Remnants more interesting, complex, and varied. The goal is to expand upon Project Remnants' existing safehouse systems, giving players more control over their community while introducing new mechanics and other quality-of-life changes.

Safehouse Expanded is designed to be modular. Each major feature is developed independently of each other (with some level of integration between modules, when applicable) and packaged into a single addon, with modules being toggleable and configurable through your save's Sandbox Options.

**Currently, Safehouse Expanded includes the Advanced Scheduler module, with more features planned for future updates.**

## Current Modules

### Advanced Scheduler

Rather than having to manually assign survivors different jobs throughout the day, Advanced Scheduler introduces a RimWorld-inspired scheduler that allows players to organize their safehouse's daily routines.

Survivors can be assigned different shifts throughout the day, letting you set up guard shifts, breaks, and more. Now your people don't just stand around doing the same task all day—your cook might make meals three times a day, but in between they can guard or haul.

**Features:**
- 24-hour scheduling: Assign a different activity for each hour of the day.
- Individual schedules: Each safehouse resident has their own routine, work shifts, and designated sleep times.
- Jobs: Schedule any safehouse job, including guarding, hauling, farming, cooking, logging, and more.
- New sleep job: Added sleep jobs, allowing you to give your NPCs dedicated sleep times.
- Persistent schedules: Schedules are retained through game sessions, and when NPCs leave/join your party.
- Copying: Copy a survivor's schedule to all others with a single button press.
- Automatic job switching: Every hour, survivors check what job they're supposed to be doing, and their assigned job changes accordingly.
- Integrated into existing Remnants behavior and vision: If an NPC is not tired, they won't sleep—likewise, if they're tired during the day, they might go to bed despite being assigned to work. Or they may choose to rest during their work time instead of working. I intended to maintain Pat's vision of having NPCs be more than just robots who do exactly as you say.

**Planned Features:**
- Creatable/swappable presets.
- Integration into Remnants UI (rather than being a separate menu).
- Improved access to job-specific settings per NPC when editing schedules.
- Better default schedule.

## Requirements & Sandbox Options

**Requirements:**
- Project Zomboid Build 42.20+
- Project Remnants

Safehouse Expanded requires Project Remnants to function.

**Sandbox Options:**

Safehouse Expanded supports enabling or disabling individual modules through your save's Sandbox Options. Currently, you can toggle Advanced Scheduler on or off.

Future modules will have their own settings where applicable.

## Planned Modules

### Automations & Improvements

A handful of minor features making safehouse life a little safer, more enjoyable, or automated. These will be added over time, and not as a dedicated module.

**Planned Features:**
- Automatic stove shutoff.

### Dynamic Guard Posts

Instead of guard posts being assigned to only one NPC, guard posts are created as shared locations that are handed out on a first-come, first-served basis with priority and scheduling considerations.

*Planned for the future... ;)*

**Planned Features:**
- Shared guard posts: Guard posts come from a shared pool, meaning you do not need to manually give every NPC a guard post.
- Multiple guards per post: Each guard post will allow multiple guards, in the case of overflow.
- Priority system: Guard posts will have a priority—higher-priority guard posts are reserved first before lower-priority ones are taken.
- Scheduled hourly: Every hour, all guard posts are checked to see if a higher-priority guard post should be manned. Two NPCs never guard the same guard post.

### Visiting Survivors

Adds visiting survivors that will periodically visit your settlement to trade, request assistance, offer gifts, or ask to join your community.

*Coming after Dynamic Guard Posts.*

**Planned Features:**
- Visiting survivors: Survivors will periodically visit your settlement, asking for aid or to join you.
- Randomly visiting traders: Traders will come randomly, but always at least once per week, and never before the 3rd day.
- Generated inventories: Survivors and traders will have randomly generated inventories, and weights will be assigned to those items semi-randomly.
- Bartering system: This War of Mine-style bartering system, where there is no currency and no "point" system displayed on the screen.
- Reputation system: Your community will have a reputation with each survivor who visits you. Someone who asked for food two days ago might decide to come back and join you later. Killing a trader might make other traders more hesitant to visit you.

## Development

Safehouse Expanded is a personal project and is actively being developed. Features, functionality, and plans may change over time.

**Disclaimer:** The project aims to work alongside Project Remnants as a submod. This mod is not endorsed by the developers of Project Remnants, nor is it endorsed by The Indie Stone.

**Developed by iGalaxied.**

**AI Acknowledgement:** Code was written with AI assistance; however, it was progressively reviewed and refactored by human eyes, with a significant portion of human-written code.