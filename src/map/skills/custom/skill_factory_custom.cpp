// Copyright (c) rAthena Dev Teams - Licensed under GNU GPL
// For more information, see LICENCE in the main folder

#include "skill_factory_custom.hpp"
#include "cope_garden.hpp"

#include "../swordman/bash.hpp"

class SkillCustomBash;

std::unique_ptr<const SkillImpl> SkillFactoryCustom::create(const e_skill skill_id) const {
#if 0
	switch( skill_id ){
		case SM_BASH:
			return std::make_unique<SkillCustomBash>();

		default:
			return nullptr;
	}
#endif

	switch (skill_id) {
	case NPC_SEEDTRAP:
	case NPC_TARGET_MARKER:
	case NPC_AIMED_SHOWER:
	case NPC_BLAZING_ERUPTION:
	case NPC_BLOCK_SEAL:
	case NPC_BLOCK_EXPLOSION:
	case NPC_FROST_FIELD:
	case NPC_LIGHTNING_JUDGEMENT:
	case NPC_GROGGY_ON:
	case NPC_RESET_EFST:
	case NPC_STRIP_SHADOW:
		return std::make_unique<CopeGardenSkill>(skill_id);
	default: return nullptr;
	}
}

class SkillCustomBash : public SkillBash{
	void calculateSkillRatio(const Damage* wd, const block_list* src, const block_list* target, uint16 skill_lv, int32& base_skillratio, int32 mflag) const override{
		// Normal Bash:
		// Base 100% + 30% per level
		// base_skillratio += 30 * skill_lv;

		// But my custom Bash Skill is stronger:
		// Base 100% + 300% per level
		base_skillratio += 300 * skill_lv;
	}
};
