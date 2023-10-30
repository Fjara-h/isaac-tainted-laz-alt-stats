import {
  CollectibleType,
  Difficulty,
  LevelStage,
  ModCallback,
  PlayerVariant,
  SeedEffect,
} from "isaac-typescript-definitions";
import {
  ISCFeature,
  ModCallbackCustom,
  canRunUnlockAchievements,
  getTearsStat,
  isMultiplayer,
  isTaintedLazarus,
  upgradeMod,
} from "isaacscript-common";

const MOD_FEATURES = [
  ISCFeature.TAINTED_LAZARUS_PLAYERS,
  ISCFeature.SAVE_DATA_MANAGER,
  ISCFeature.CHARACTER_HEALTH_CONVERSION,
] as const;
const MOD_NAME = "Tainted Lazarus Alt Stats";
const MOD_NAME_SHORT = "T.Laz Alt Stats";
const modVanilla = RegisterMod(MOD_NAME, 1);
const mod = upgradeMod(modVanilla, MOD_FEATURES);
const MAJOR_VERSION = "2";
const MINOR_VERSION = "1";

const font = Font();
font.Load("font/luaminioutlined.fnt");

const transparencies: number[] = [
  0.1, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 0.8, 0.9, 1,
];

const v = {
  // Never resets.
  persistent: {
    display: true,
    x: 36,
    y: 80,
    xShift: 0,
    yShift: 16,
    interval: 12,
    scale: 1,
    alpha: 2,
    alphaBirthright: 4,
  },
  // Reset at the beginning of every run.
  run: {
    hasFlipped: false,
    hasBirthright: false,
    speed: 0.9,
    tears: 2.5,
    damage: 5.25,
    range: 6.5,
    shotspeed: 1,
    luck: -2,
    addXShift: 0,
    addYShift: 0,
    playerCount: 0,
    hudOffset: 0,
    numSeedEffect: 0,
    victoryLapCount: 0,
  },
};
mod.saveDataManager("main", v);

export function main(): void {
  mod.AddCallback(ModCallback.POST_RENDER, postRender);
  mod.AddCallbackCustom(
    ModCallbackCustom.POST_PLAYER_CHANGE_TYPE,
    setHasBirthright,
    PlayerVariant.PLAYER,
  );
  mod.AddCallbackCustom(
    ModCallbackCustom.POST_PLAYER_UPDATE_REORDERED,
    setHasBirthright,
  );
  mod.AddCallbackCustom(
    ModCallbackCustom.POST_GAME_STARTED_REORDERED,
    setHasBirthright,
    true,
  );
  mod.AddCallbackCustom(ModCallbackCustom.POST_FIRST_FLIP, registerPreFlip);
  mod.AddCallbackCustom(ModCallbackCustom.POST_FLIP, postFlip);
  Isaac.DebugString(`${MOD_NAME} initialized.`);
  setupMyModConfigMenuSettings();
}

function updatePosition() {
  if (
    !canRunUnlockAchievements() ||
    Game().Difficulty === Difficulty.HARD ||
    Game().IsGreedMode()
  ) {
    v.run.addXShift = v.persistent.xShift;
    v.run.addYShift = v.persistent.yShift;
  } else {
    v.run.addXShift = 0;
    v.run.addYShift = 0;
  }
  v.run.addXShift += Options.HUDOffset * 20;
  v.run.addYShift += Options.HUDOffset * 12;
}

function updateCheck() {
  let updatePos = false;
  const activePlayers = Game().GetNumPlayers();

  for (let i = 0; i < activePlayers; i++) {
    const player = Isaac.GetPlayer(i);
    if (player.FrameCount === 0) {
      // do i need didplayerchange or diddualitychange?(not duality i think)
      updatePos = true;
    }
  }

  if (v.run.playerCount !== activePlayers) {
    updatePos = true;
    v.run.playerCount = activePlayers;
  }

  if (v.run.hudOffset !== Options.HUDOffset) {
    updatePos = true;
    v.run.hudOffset = Options.HUDOffset;
  }

  if (v.run.victoryLapCount !== Game().GetVictoryLap()) {
    updatePos = true;
    v.run.victoryLapCount = Game().GetVictoryLap();
  }

  if (v.run.numSeedEffect !== Game().GetSeeds().CountSeedEffects()) {
    updatePos = true;
    v.run.numSeedEffect = Game().GetSeeds().CountSeedEffects();
  }

  if (updatePos) {
    updatePosition();
  }
}

function postRender() {
  const player = Isaac.GetPlayer(0);
  if (
    !isTaintedLazarus(player) ||
    !v.persistent.display ||
    !Game().GetHUD().IsVisible() ||
    Game().GetLevel().GetStage() === LevelStage.HOME ||
    Game().GetSeeds().HasSeedEffect(SeedEffect.NO_HUD) ||
    isMultiplayer() ||
    !Options.FoundHUD
  ) {
    return;
  }
  updateCheck();
  const statCoordsX: number =
    v.persistent.x + v.run.addXShift + Game().ScreenShakeOffset.X;
  const statCoordsY: number =
    v.persistent.y + v.run.addYShift + Game().ScreenShakeOffset.Y;
  const alpha: number = v.run.hasBirthright
    ? transparencies[v.persistent.alphaBirthright] ?? 0.4
    : transparencies[v.persistent.alpha] ?? 0.2;

  font.DrawStringScaled(
    v.run.speed.toFixed(2),
    statCoordsX,
    statCoordsY,
    v.persistent.scale,
    v.persistent.scale,
    KColor(1, 1, 1, alpha),
    0,
    true,
  );
  font.DrawStringScaled(
    v.run.tears.toFixed(2),
    statCoordsX,
    statCoordsY + v.persistent.interval,
    v.persistent.scale,
    v.persistent.scale,
    KColor(1, 1, 1, alpha),
    0,
    true,
  );
  font.DrawStringScaled(
    v.run.damage.toFixed(2),
    statCoordsX,
    statCoordsY + v.persistent.interval * 2,
    v.persistent.scale,
    v.persistent.scale,
    KColor(1, 1, 1, alpha),
    0,
    true,
  );
  font.DrawStringScaled(
    v.run.range.toFixed(2),
    statCoordsX,
    statCoordsY + v.persistent.interval * 3,
    v.persistent.scale,
    v.persistent.scale,
    KColor(1, 1, 1, alpha),
    0,
    true,
  );
  font.DrawStringScaled(
    v.run.shotspeed.toFixed(2),
    statCoordsX,
    statCoordsY + v.persistent.interval * 4,
    v.persistent.scale,
    v.persistent.scale,
    KColor(1, 1, 1, alpha),
    0,
    true,
  );
  font.DrawStringScaled(
    v.run.luck.toFixed(2),
    statCoordsX,
    statCoordsY + v.persistent.interval * 5,
    v.persistent.scale,
    v.persistent.scale,
    KColor(1, 1, 1, alpha),
    0,
    true,
  );
}

function setHasBirthright() {
  const player = Isaac.GetPlayer(0);
  if (isTaintedLazarus(player)) {
    const sub = mod.getTaintedLazarusSubPlayer(player);
    if (player.HasCollectible(CollectibleType.BIRTHRIGHT, true)) {
      v.run.hasBirthright = true;
    } else if (sub !== undefined) {
      // This must be done in order to avoid crashing.
      // eslint-disable-next-line unicorn/no-lonely-if
      if (sub.HasCollectible(CollectibleType.BIRTHRIGHT)) {
        v.run.hasBirthright = true;
      }
    }
  }
}

function registerPreFlip(_: EntityPlayer, newLazarus: EntityPlayer) {
  mod.getTaintedLazarusSubPlayer(newLazarus);
  setHasBirthright();
  mod.AddCallback(ModCallback.PRE_USE_ITEM, preFlip, CollectibleType.FLIP);
}

function preFlip(
  _collectibleType: CollectibleType,
  _rng: RNG,
  player: EntityPlayer,
) {
  if (isTaintedLazarus(player) && v.run.hasBirthright) {
    preUpdateStatsBirthright(player);
  }
  return undefined;
}

function postFlip(_: EntityPlayer, oldLazarus: EntityPlayer) {
  updateStats(oldLazarus);
}

function updateStats(player: EntityPlayer) {
  if (!v.run.hasBirthright) {
    v.run.speed = player.MoveSpeed;
    v.run.damage = player.Damage;
  }
  v.run.tears = getTearsStat(player.MaxFireDelay);
  v.run.range = player.TearRange / 40;
  v.run.shotspeed = player.ShotSpeed;
  v.run.luck = player.Luck;
}

function preUpdateStatsBirthright(subPlayer: EntityPlayer) {
  v.run.speed = subPlayer.MoveSpeed;
  v.run.damage = subPlayer.Damage;
}

function setupMyModConfigMenuSettings() {
  if (ModConfigMenu !== undefined) {
    const categoryID = ModConfigMenu.GetCategoryIDByName(MOD_NAME_SHORT);
    if (categoryID !== undefined) {
      ModConfigMenu.MenuData.set(categoryID, {
        Name: MOD_NAME_SHORT,
        Subcategories: [],
      });
    }

    // Info
    ModConfigMenu.AddSpace(MOD_NAME_SHORT, "Info");
    ModConfigMenu.AddText(MOD_NAME_SHORT, "Info", MOD_NAME);
    ModConfigMenu.AddSpace(MOD_NAME_SHORT, "Info");
    ModConfigMenu.AddText(
      MOD_NAME_SHORT,
      "Info",
      `${MAJOR_VERSION}.${MINOR_VERSION}`,
    );

    // Stats
    ModConfigMenu.AddSetting(MOD_NAME_SHORT, "Stats", {
      Type: ModConfigMenuOptionType.BOOLEAN,
      Display: () => `Display stats: ${v.persistent.display}`,
      CurrentSetting: () => v.persistent.display,
      OnChange: (newValue: number | boolean | undefined) => {
        v.persistent.display = newValue as boolean;
      },
      Info: ["Display non-active tainted lazarus stats on the screen."],
    });
    ModConfigMenu.AddSetting(MOD_NAME_SHORT, "Stats", {
      Type: ModConfigMenuOptionType.NUMBER,
      Display: () => `Position X: ${v.persistent.x}`,
      Maximum: 500,
      Minimum: 0,
      ModifyBy: 1,
      CurrentSetting: () => v.persistent.x,
      OnChange: (newValue: number | boolean | undefined) => {
        v.persistent.x = newValue as number;
      },
      Info: ["Default = 36"],
    });
    ModConfigMenu.AddSetting(MOD_NAME_SHORT, "Stats", {
      Type: ModConfigMenuOptionType.NUMBER,
      Display: () => `Position Y: ${v.persistent.y}`,
      Maximum: 500,
      Minimum: 0,
      ModifyBy: 1,
      CurrentSetting: () => v.persistent.y,
      OnChange: (newValue: number | boolean | undefined) => {
        v.persistent.y = newValue as number;
      },
      Info: ["Default = 80"],
    });
    ModConfigMenu.AddSetting(MOD_NAME_SHORT, "Stats", {
      Type: ModConfigMenuOptionType.NUMBER,
      Display: () => `Horizontal shift: ${v.persistent.xShift}`,
      Maximum: 100,
      Minimum: 0,
      ModifyBy: 1,
      CurrentSetting: () => v.persistent.xShift,
      OnChange: (newValue: number | boolean | undefined) => {
        v.persistent.xShift = newValue as number;
        updatePosition();
      },
      Info: [
        "'X' position UI-shift for hard difficulty, greed mode, or non-achievement runs.",
        "Default = 0",
      ],
    });
    ModConfigMenu.AddSetting(MOD_NAME_SHORT, "Stats", {
      Type: ModConfigMenuOptionType.NUMBER,
      Display: () => `Vertical shift: ${v.persistent.yShift}`,
      Maximum: 100,
      Minimum: 0,
      ModifyBy: 1,
      CurrentSetting: () => v.persistent.yShift,
      OnChange: (newValue: number | boolean | undefined) => {
        v.persistent.yShift = newValue as number;
        updatePosition();
      },
      Info: [
        "'Y' position UI-shift for hard difficulty, greed mode, or non-achievement runs.",
        "Default = 16",
      ],
    });
    ModConfigMenu.AddSetting(MOD_NAME_SHORT, "Stats", {
      Type: ModConfigMenuOptionType.NUMBER,
      Display: () => `Vertical space between stats: ${v.persistent.interval}`,
      Maximum: 100,
      Minimum: 0,
      ModifyBy: 1,
      CurrentSetting: () => v.persistent.interval,
      OnChange: (newValue: number | boolean | undefined) => {
        v.persistent.interval = newValue as number;
      },
      Info: ["Default = 12"],
    });
    ModConfigMenu.AddSetting(MOD_NAME_SHORT, "Stats", {
      Type: ModConfigMenuOptionType.NUMBER,
      Display: () => `Scale: ${v.persistent.scale}`,
      Maximum: 2,
      Minimum: 0.5,
      ModifyBy: 0.25,
      CurrentSetting: () => v.persistent.scale,
      OnChange: (newValue: number | boolean | undefined) => {
        v.persistent.scale = newValue as number;
      },
      Info: ["Default = 1"],
    });
    ModConfigMenu.AddSetting(MOD_NAME_SHORT, "Stats", {
      Type: ModConfigMenuOptionType.NUMBER,
      Display: () => `Transparency: ${v.persistent.alpha}`,
      Maximum: 11,
      Minimum: 1,
      ModifyBy: 1,
      CurrentSetting: () => v.persistent.alpha,
      OnChange: (newValue: number | boolean | undefined) => {
        v.persistent.alpha = newValue as number;
      },
      Info: [
        "Transparency of stat numbers without birthright.",
        "Default = 2",
        "0.1, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 0.8, 0.9, 1",
      ],
    });
    ModConfigMenu.AddSetting(MOD_NAME_SHORT, "Stats", {
      Type: ModConfigMenuOptionType.NUMBER,
      Display: () => `Transparency: ${v.persistent.alphaBirthright}`,
      Maximum: 11,
      Minimum: 1,
      ModifyBy: 1,
      CurrentSetting: () => v.persistent.alphaBirthright,
      OnChange: (newValue: number | boolean | undefined) => {
        v.persistent.alphaBirthright = newValue as number;
      },
      Info: [
        "Transparency of stat numbers with birthright.",
        "Default = 4",
        "0.1, 0.2, 0.25, 0.3, 0.4, 0.5, 0.6, 0.75, 0.8, 0.9, 1",
      ],
    });

    Isaac.DebugString(`${MOD_NAME} MCM initialized.`);
  }
}
