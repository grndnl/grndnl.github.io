# Generates AGENTS.md from the site's data sources at Jekyll build time
# and writes it to the built site (so it is downloadable from /AGENTS.md).
#
# Sources are parsed by AgentsMd::Builder (see _plugins/agents_md_builder.rb).
# To also refresh the repo-root AGENTS.md (used by AI agents that read the
# repo directly, not just visitors of the built site), run:
#
#     bundle exec ruby scripts/build_agents_md.rb
#
# The generator below NEVER writes back into the repo source tree to avoid
# triggering Jekyll's file watcher in a regenerate loop during `jekyll serve`.

require_relative "agents_md_builder"

module Jekyll
  class AgentsMdGenerator < Generator
    safe true
    priority :low

    def generate(site)
      builder = AgentsMd::Builder.new(site.source)
      content = builder.build

      site.static_files << GeneratedAgentsMdFile.new(site, content)
    rescue StandardError => e
      Jekyll.logger.warn "AGENTS.md", "Failed to generate AGENTS.md: #{e.class}: #{e.message}"
      Jekyll.logger.debug "AGENTS.md", e.backtrace.first(10).join("\n") if e.backtrace
    end
  end

  # In-memory static file: emits AGENTS.md directly into the site root
  # without needing a real source file to copy from.
  class GeneratedAgentsMdFile < StaticFile
    def initialize(site, content)
      @content = content
      @generated_path = "AGENTS.md"
      super(site, site.source, "", @generated_path)
    end

    def write(dest)
      dest_path = File.join(dest, @generated_path)
      FileUtils.mkdir_p(File.dirname(dest_path))
      File.write(dest_path, @content)
      true
    end

    # Skip modification-time checks; we always rewrite.
    def modified?
      true
    end
  end
end
