require "open3"

# Runs Claude Code headless (`claude -p`) on the local subscription and returns
# the structured JSON that matches +schema+.
class ClaudeClient
  class Error < StandardError; end

  BIN = ENV.fetch("CLAUDE_BIN", "claude")
  WORKDIR = Rails.root.join("storage", "claude")

  def self.json(prompt, schema:, system: nil, model: "sonnet", timeout: 600)
    WORKDIR.mkpath
    args = [ BIN, "-p", "--output-format", "json", "--json-schema", schema.to_json,
             "--tools", "", "--no-session-persistence", "--strict-mcp-config", "--setting-sources", "",
             "--model", model ]
    args += [ "--system-prompt", system ] if system
    out, err, status = Open3.capture3("timeout", timeout.to_s, *args, stdin_data: prompt, chdir: WORKDIR.to_s)
    raise Error, "claude נכשל (#{status.exitstatus}): #{err.presence || out}".truncate(800) unless status.success?
    data = JSON.parse(out)
    raise Error, "claude החזיר שגיאה: #{data['result']}".truncate(800) if data["is_error"]
    data["structured_output"] || JSON.parse(data["result"])
  rescue JSON::ParserError => e
    raise Error, "תשובה לא תקינה מ-claude: #{e.message}"
  end
end
