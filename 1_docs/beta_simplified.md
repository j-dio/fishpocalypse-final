Aesthetic:

- Pixel Retro, fixed camera perspective, 2.5D, characters are pixels, environment is 3D

Environment:

- Fixed environment

Goal:

- No end goal, just survive as N many nights as possible

State/Day system:

- Controls day/night cycle
- Every (10th, 20th, ...) day spawns a buff after the wave ends
- Enables Spawn Enemy System and Spawn Buff System

Gameplay:

- Survive n amount of days; makes fish more frequent
- Day: you fish
- Night: you survive a lot of angry fish

Player system:

- HP
- CP (cast points, mana system for abilities)
- SP (stamina points)
- Inventory slots (based on inventory system)
- Combat system:
- Shooting uses Recharge Cost/shot and CP
- Dodging uses SP

Inventory system:

- Pole slot: your fishing pole
- Main slot: primary weapon
- Secondary slot: secondary weapon
- Two item slots: HP, shield, buffs
- Stores → (FishWeapons[], HealingItem[], FishingPoles[])

Fishing system:

- Refer to Stardew Valley
- Produces → (FishWeapons[], HealingItems[], FishingPoles[])

Fish system:

- Fish that can be caught can be either a weapon or an item
- Some only appear after n days (balancing)

Fish weapon attribute:

- Rarity (multiplier for base stats)
- Spawns only after nth day
- Damage/second
- Projectiles/shot
- Recharge Cost/shot
- delay after shot

Rarity system:

- Affects base stats of all weapons
- Rarity array: [common, uncommon, rare, epic, legendary, "???"]

Enemy pool:

- Normal Fish: melee attack
- Tanky Fish: high damage melee attack
- Shooting Fish: ranged projectile attack

Spawn Enemy system:

- Spawns n amount of fish per night
- Spawn distribution based on fish rarity
- Total population grows by scaling factor over time
- Spawns → (Normal Fish, Tanky Fish, Shooting Fish)

Spawn Item system:

- Spawns all items, weapons, buffs
- Items spawn with randomized velocity + gravity, scattering around drop point (e.g., player)

Item pool:

- FishWeapons array [idk how many]
- HealingItem array [class I, class II, class III, class IV]
- FishingPoles array [normal, reinforced, fish pole variant]
- Buffs array [idk how many]

Spawn Buff system:

- Buffs array []
- Buffs improve player stats

Legend:
CJ, DIO, GLS, SEN

Relations:
Player → has → (Inventory System, Fishing System, Combat System, Buff System) - CJ
State/Day System → enables → (Spawn Enemy System, Spawn Buff System) - SEN
Fishing System → produces → (FishWeapons[], HealingItems[], FishingPoles[]) - DIO
Inventory System → stores → (FishWeapons[], HealingItems[], FishingPoles[]) - CJ
Rarity System → modifies → (all FishWeapons stats)
Spawn Enemy System → spawns → (Normal Fish, Tanky Fish, Shooting Fish) => this can only be done if there already is a list of enemies
Spawn Item System → spawns → (all items, weapons, buffs) => this can only be done if there already is a list of items, weapons, buffs

non-system:
array of enemies[abstract enemy] - SEN
array of class Items[fishweapons[], healingItems[], fishPole]
3 of them are under the Item class
array of fishWeapons[nth elements of abstract weapon]
array of healingItems[4 abstract healingItems]
array of fishingPole[nth elements of abstract fishPole]
array of buffs[nth elements of abstract buff]
array of rarity[nth elements of abstract rarity]

CLASSES:

1. ITEM ABSTRACT CLASS & DB:
   abstract class item{
   Name
   Description
   Sprite
   }

class itemsDB{
fishWeapons[]
healingItems[]
fishingPole[]
}

2.  RARITY AND PRIMARY BUFF CLASS:
    abstract class Rarity{
    Name
    Color

        WeaponMultiplier

    ShotDelayMultiplier
    LureMultiplier
    CostMultiplier
    }

abstract class Buff{
Name
Description
Sprite

    Stackable

    PlayerEffects playerEffects
    WeaponEffects weaponEffects
    EnemyEffects enemyEffects
    SpawnEffects spawnEffects

}

3. SPECIFIED BUFFS
   class PlayerEffects{
   MoveSpeedMultiplier
   DamageTakenMultiplier
   }

class WeaponEffects{
DamageMultiplier
ShotDelayMultiplier
ProjectileSpeedMultiplier
CostMultiplier
}

class EnemyEffects{
HPMultiplier
DamageMultiplier
SpeedMultiplier
AttackDelayMultiplier
}

class SpawnEffects{
FishSpawnMultiplier
EnemySpawnMultiplier
LootSpawnMultiplier
}

4.  PROJECTILE ABSTRACT CLASS:
    abstract class Projectile{
    Owner // Weapon || Enemy
    Speed
    Damage
    LifeTime
    Sprite
    }

5.  WEAPON ABSTRACT CLASS:
    abstract class Weapon : Item{
    SpawnDay
    BaseDamagePerShot
    BaseShotDelay
    BaseProjectilesPerShot
    BaseRechargeCost

        Rarity rarity
        Projectile projectile

        ActiveBuffs[check player buffs()]

        GetDamage(){
        	final = BaseDamagePerSecond * rarity.DamgeMultiplier
        	for buff in ActiveBuffs:
        		final *= buff.weaponEffects.DamageMultiplier
        	return final
        }

        GetShotDelay(){
        	final = BaseShotDelay * rarity.ShotDelayMultiplier
        	for buff in ActiveBuffs:
        		final *= buff.weaponEffects.ShotDelayMultiplier
        	return final
        }

        GetCost(){
        	final = BaseRechargeCost * rarity.CostMultiplier
        	for buff in ActiveBuffs:
        		final *= buff.weaponEffects.CostMultiplier
        	return final
        }

    }

6.  HEALING ITEM ABSTRACT CLASS:
    abstract class HealingItem : Item{
    BaseHealAmount
    UseDelay
    StackLimit

        Rarity rarity
        GetHeal(){
        	return BaseHealAmount * rarity.HealMultiplier
        }

    }

7.  FISHING POLE ABSTRACT CLASS:
    abstract class FishPole : Item{
    BaseBarSize
    BaseLureSpeed
    BaseLureChance

        Rarity rarity
        ActiveBuffs[]

        GetLureChance(){
        	final = BaseLureChance * rarity.LureMultiplier
        	return final
        }

    }

8.  ENEMY ABSTRACT CLASS:
    abstract class Enemy{
    HierarchyTier // 1=basic, 2=normal, … , 5 = elite, etc.
    SpawnWeight // Used for random selection
    BaseHP
    BaseSpeed
    BaseDamage
    ProjectilesPerShot

        CanShoot
        BaseAttackDelay

        Sprite
        Projectile projectile

        ActiveBuffs[]
        GetHP(){
        	final = BaseHP
        	for buff in ActiveBuffs:
        		final *= buff.enemyEffects.HPMultiplier
        	return final
        }

        GetDamage(){
        	final = BaseDamage
        	for buff in ActiveBuffs:
        		final *= buff.enemyEffects.DamageMultiplier
        	return final
        }

        GetSpeed(){
        	final = BaseSpeed
        	for buff in ActiveBuffs:
        		final *= buff.enemyEffects.SpeedMultiplier
        	return final
        }

        GetAttackDelay(){
        	final = BaseAttackDelay
        	for buff in ActiveBuffs:
        		final *= buff.enemyEffects.AttackDelayMultiplier
        	return final
        }

    }
    9.  SPAWN SYSTEM REFERENCE (suggestion)

    | Code | Notes |
    | ---- | ----- |

    | `gdscript
class SpawnContext{
    HPMultiplier = 1
    DamageMultiplier = 1
    SpeedMultiplier = 1
    SpawnRateMultiplier = 1
}
` | Precomputed values from `ActiveBuffs`. Used to avoid recalculating buffs per enemy spawn. |
    | `gdscript
GetPopulationTarget(){
    return BasePopulation
        * (1 + CurrentNight * 0.25)
        * cachedContext.SpawnRateMultiplier
}
` | Computes the desired population to spawn this night. Scales with `CurrentNight` and `SpawnRateMultiplier`. |
    | `gdscript
ApplySpawnContext(enemy){
    enemy.HP *= cachedContext.HPMultiplier
    enemy.Damage *= cachedContext.DamageMultiplier
    enemy.Speed *= cachedContext.SpeedMultiplier
}
` | Applies the precomputed multipliers from `SpawnContext` to a newly spawned enemy. Runs in O(1) per enemy. |
    | `gdscript
SpawnEnemy(){
    enemyType = WeightedRandomSelect(EnemyPool)
    enemy = Instantiate(enemyType)
    ApplySpawnContext(enemy)
    CurrentPopulation++
    AddToWorld(enemy)
}
` | Creates one enemy from the pool using weighted random selection, applies `SpawnContext`, adds it to the world and increments population. |
    | ```gdscript
    BuildSpawnContext(){
    context = new SpawnContext()
    for buff in ActiveBuffs:
    context.HPMultiplier _= buff.enemyEffects.HPMultiplier
    context.DamageMultiplier _= buff.enemyEffects.DamageMultiplier
    context.SpeedMultiplier _= buff.enemyEffects.SpeedMultiplier
    context.SpawnRateMultiplier _= buff.spawnEffects.EnemySpawnMultiplier
    return context
    }

    ````| Reads all active buffs once and converts them into cached multipliers (HP, damage, speed, spawn rate). Avoids recalculating buffs for every enemy. |
    | ```gdscript
    class SpawnSystem{
        EnemyPool[]
        ActiveBuffs[]
        BasePopulation
        CurrentPopulation
        SpawnContext cachedContext

        UpdateSpawn(){
            TargetPopulation = GetPopulationTarget()
            while(CurrentPopulation < TargetPopulation){
                SpawnEnemy()
            }
        }
    }
    ``` | Designed to avoid O(N x B) complexity (N=enemies, B=buffs). Buffs are precomputed once (O(B)) into `SpawnContext`, then applied per enemy in O(1), making large-scale spawning (e.g., 1000+ enemies) efficient and stable. |
    ````
