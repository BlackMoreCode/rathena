// Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
// Garden of Time mechanics adapted from crazyarashi's script collection.
#pragma once

#include "../skill_impl.hpp"
#include "map/clif.hpp"
#include "map/status.hpp"
#include "common/random.hpp"

// Keep these fork-only mechanics in the custom factory. No existing skill or
// global DamageTaken percentage is replaced when adding the two instances.
class CopeGardenSkill final : public SkillImpl {
public:
    explicit CopeGardenSkill(e_skill id) : SkillImpl(id) {}

    void modifyDamageData(Damage& damage, const block_list&, const block_list&, uint16 level) const override {
        if (getSkillId() == NPC_SEEDTRAP && level)
            damage.damage = 10000 + 10000 * level - 5000 * (rnd() % (level + 2));
    }

    void castendNoDamageId(block_list* src, block_list* target, uint16 level, t_tick tick, int32& flag) const override {
        if (!src || !target || !level) return;
        auto* sc = status_get_sc(target);
        const auto id = getSkillId();
        if (id == NPC_RESET_EFST) {
            // Respect upstream clearance exclusions, especially the encounter's
            // own markers. Do not clear by raw numeric status ranges.
            if (sc) for (const auto& entry : status_db) {
                auto type = static_cast<sc_type>(entry.first);
                if (sc->getSCE(type) && !entry.second->flag[SCF_NOCLEARANCE]) {
                    if (type == SC_BERSERK || type == SC_SATURDAYNIGHTFEVER)
                        sc->getSCE(type)->val2 = 0;
                    status_change_end(target, type);
                }
            }
        } else if (id == NPC_STRIP_SHADOW) {
            clif_skill_nodamage(src, *target, id, level, skill_strip_equip(src, target, id, level));
            return;
        } else if (id == NPC_GROGGY_ON || (flag & 1)) {
            if (id == NPC_BLOCK_SEAL) {
                if (!sc || !sc->getSCE(SC_COPE_TARGET_MARKER)) return;
                status_change_end(target, SC_COPE_TARGET_MARKER);
            }
            if (id == NPC_FROST_FIELD && sc && sc->getSCE(SC_COPE_WARM_SHIELD)) return;
            status_change_start(src, target, skill_get_sc(id), 10000, level, 0, 0, 0,
                skill_get_time(id, level), SCSTART_NOAVOID | SCSTART_NOTICKDEF | SCSTART_NORATEDEF);
        } else {
            const bool damage = id == NPC_AIMED_SHOWER || id == NPC_BLAZING_ERUPTION ||
                id == NPC_BLOCK_EXPLOSION || id == NPC_LIGHTNING_JUDGEMENT;
            map_foreachinallrange(skill_area_sub, src, skill_get_splash(id, level), BL_CHAR,
                src, id, level, tick, flag | BCT_ENEMY | 1,
                damage ? skill_castend_damage_id : skill_castend_nodamage_id);
        }
        clif_skill_nodamage(src, *target, id, level);
    }

    void castendDamageId(block_list* src, block_list* target, uint16 level, t_tick tick, int32& flag) const override {
        if (!src || !target || !level) return;
        const auto id = getSkillId();
        auto* sc = status_get_sc(target);
        sc_type required = SC_NONE;
        if (id == NPC_AIMED_SHOWER || id == NPC_BLAZING_ERUPTION) required = SC_COPE_TARGET_MARKER;
        if (id == NPC_BLOCK_EXPLOSION) required = SC_COPE_BLOCK_SEAL;
        if (required != SC_NONE) {
            if (!sc || !sc->getSCE(required)) return;
            status_change_end(target, required);
        }
        skill_attack(skill_get_type(id), src, src, target, id, level, tick, flag);
    }

    void castendPos2(block_list* src, int32 x, int32 y, uint16 level, t_tick, int32& flag) const override {
        if (src && level && getSkillId() == NPC_SEEDTRAP)
            skill_unitsetting(src, getSkillId(), level, x, y, flag);
    }

    void calculateSkillRatio(const Damage*, const block_list*, const block_list* target,
        uint16 level, int32& ratio, int32) const override {
        // Preserve the source pack's encounter ratios; these are custom balance,
        // not a claim of official kRO formulas. Other skills retain upstream math.
        switch (getSkillId()) {
        case NPC_AIMED_SHOWER: case NPC_BLAZING_ERUPTION: ratio += -100 + 4000 + 200 * level; break;
        case NPC_BLOCK_EXPLOSION: ratio += -100 + 3000 + 200 * level; break;
        case NPC_LIGHTNING_JUDGEMENT:
            ratio += -100 + 2000 + 200 * level;
            if (target) {
                auto* sc = status_get_sc(target);
                if (sc && sc->getSCE(SC_COPE_FROST_STORM)) ratio += 3000;
            }
            break;
        default: break;
        }
    }
};
