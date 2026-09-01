import { formatSkillsForPrompt, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

/**
 * Global disable-model-invocation override for Pi skills.
 *
 * This preserves loaded skills and /skill:name commands, but removes the
 * auto-discoverable skills block from the system prompt on every agent run.
 *
 * Net effect: all skills behave as if they had
 * `disable-model-invocation: true` in frontmatter, without modifying the
 * skill files themselves.
 */
export default function disableModelSkillInvocation(pi: ExtensionAPI) {
	pi.on("before_agent_start", async (event) => {
		const skills = event.systemPromptOptions.skills ?? [];
		if (skills.length === 0) {
			return undefined;
		}

		// This matches Pi's native behavior: only skills visible to the model are
		// listed in the prompt. Hidden skills (disable-model-invocation: true)
		// are already filtered out by formatSkillsForPrompt().
		const renderedSkillBlock = formatSkillsForPrompt(skills);
		if (!renderedSkillBlock) {
			return undefined;
		}

		let systemPrompt = event.systemPrompt;

		if (systemPrompt.includes(renderedSkillBlock)) {
			systemPrompt = systemPrompt.replace(renderedSkillBlock, "");
		} else {
			// Fallback in case another extension has slightly reshaped the prompt
			// while leaving the standard skill section intact.
			systemPrompt = systemPrompt.replace(
				/\n\nThe following skills provide specialized instructions for specific tasks\.\nUse the read tool to load a skill's file when the task matches its description\.\nWhen a skill file references a relative path, resolve it against the skill directory \(parent of SKILL\.md \/ dirname of the path\) and use that absolute path in tool commands\.\n\n<available_skills>[\s\S]*?<\/available_skills>/,
				"",
			);
		}

		return { systemPrompt };
	});
}
