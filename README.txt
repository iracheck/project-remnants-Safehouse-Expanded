Remnants Hourly Scheduler — experimental Lua submod (Build 42)

INSTALLATION:
Copy the RemnantsHourlyScheduler folder (the folder containing 42/) into your Project Zomboid local mods directory, then enable it alongside Project Remnants.

USAGE:
Open Remnants faction management > Members & Jobs > Open Hourly Scheduler. Select a BASE_RESIDENT, select task in dropdown, and click hour slots to assign it. Task blocks repeat daily. Copy day to all residents or Apply current hour now.

DETAILS:
- Existing per-member job dropdowns are suppressed; other Remnants management controls remain.
- Job IDs are pulled from npcfwGetSafehouseJobDefs().
- Idle removes safehouse job (NONE). Sleep removes job and calls npcfwOrderSafehouseSleep if allowed.
- Schedules persist in local player's modData within the save.
- Scheduler runs at in-game hourly boundaries; apply button forces current hour.

LIMITATIONS / TESTING:
- Not run inside the game: compatibility with your exact Remnants and PZ builds must be tested.
- BASE_RESIDENT NPCs only; other roster members are omitted intentionally.
- Java's fatigue, automatic sleeping, and job-rest systems remain active. Scheduler does not forcibly wake NPCs or interrupt sleep.
- Sleep orders may be rejected if no free sleeping place; retry happens next hour.
- A change from Sleep to an assigned job is issued, but may not wake a sleeping NPC.
- Job assignment might return false when already assigned; if so the addon retries on later boundaries.
- Other UI entry points for immediate orders remain available.
- If another addon patches the same Members methods after this one, load order may override this patch.
- Saved schedules are associated with the player character; single player is the intended target.
- Community mod: no Java code bundled, no Remnants source redistributed.
