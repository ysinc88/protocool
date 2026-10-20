# Agent instructions

Everything you need to install, configure and run Protocool is in [README.md](README.md). Start at
"For AI agents installing this", then follow "Installation" in order and run each verification step.

Rules:
- Ask the human for the Gmail address + App Password (guide them with the README section) and committee details; never for their Google password.
- Never expose the app publicly (no auth). Never e-mail real members as a test; use the committee's own address.
- Background jobs only run with `SOLID_QUEUE_IN_PUMA=1` (or `bin/jobs`).
- Keep UI strings, e-mails and prompts in Hebrew unless asked to translate (README: "Adapting to another language").
