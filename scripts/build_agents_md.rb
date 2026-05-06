#!/usr/bin/env ruby
# frozen_string_literal: true

# Regenerates the repo-root AGENTS.md from existing site data sources.
#
# Run:
#     bundle exec ruby scripts/build_agents_md.rb
#
# This shares its logic with the Jekyll generator
# (_plugins/copy-agents-md.rb) via _plugins/agents_md_builder.rb.
# Run this before committing whenever you update:
#   - _pages/about.md             (bio / subtitle)
#   - assets/json/resume.json     (work, education, skills)
#   - _projects/*.md              (project cards)
#   - _bibliography/papers.bib    (publications, patents)
#   - _data/repositories.yml      (GitHub repos / users)
#   - _data/socials.yml           (contact links)
#
# The generated file is intended to be committed to the repo so AI agents
# (Cursor, Copilot, etc.) that look at the repo root see an up-to-date
# AGENTS.md without needing to run a Jekyll build first.

require "pathname"

ROOT = Pathname(__dir__).parent.expand_path
PLUGIN = ROOT.join("_plugins", "agents_md_builder.rb")

unless PLUGIN.exist?
  warn "Could not find #{PLUGIN}. Run this script from the repo root."
  exit 1
end

require PLUGIN.to_s

target = ROOT.join("AGENTS.md")

builder = AgentsMd::Builder.new(ROOT.to_s)
content = builder.build

if target.exist? && target.read == content
  puts "AGENTS.md is already up to date (no changes)."
else
  target.write(content)
  puts "Wrote #{target} (#{content.bytesize} bytes)."
end
