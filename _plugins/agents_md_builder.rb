# frozen_string_literal: true

# Builds AGENTS.md content from existing site data sources.
#
# Sources of truth (read by this builder):
#   - _pages/about.md             -> identity, subtitle, narrative bio
#   - assets/json/resume.json     -> education, work, skills
#   - _projects/*.md              -> featured projects (front matter only)
#   - _bibliography/papers.bib    -> publications, patents (parsed via BibTeX gem)
#   - _data/repositories.yml      -> GitHub users + featured repos
#   - _data/socials.yml           -> contact links
#
# Used by:
#   - _plugins/copy-agents-md.rb  -> writes _site/AGENTS.md at Jekyll build time
#   - scripts/build_agents_md.rb  -> writes repo-root AGENTS.md on demand
#
# Designed so any update to the underlying source files is automatically
# reflected the next time AGENTS.md is regenerated.

require "yaml"
require "json"
require "date"
require "bibtex"

module AgentsMd
  # Subset of bibtex fields we filter out of any "extra info" section.
  IGNORED_BIB_FIELDS = %w[
    abbr abstract additional_info altmetric annotation arxiv award award_name
    bibtex_show blog code google_scholar_id html inspirehep_id pdf poster
    preview selected slides supp video website eprint archivePrefix primaryClass
    url note month volume number pages booktitle organization publisher
    journal year title author editor isbn issn doi
  ].freeze

  class Builder
    attr_reader :root

    def initialize(root)
      @root = root
    end

    def build
      sections = []
      sections << header
      sections << identity_section
      sections << about_section
      sections << education_section
      sections << work_section
      sections << skills_section
      sections << projects_section
      sections << repositories_section

      pubs_by_year, patents = parse_publications
      sections << selected_publications_section(pubs_by_year)
      sections << full_publications_section(pubs_by_year)
      sections << patents_section(patents)

      sections << themes_section
      sections << how_to_use_section
      sections.compact.join("\n\n").rstrip + "\n"
    end

    # --- Source loaders ---------------------------------------------------

    def about_front_matter
      @about_front_matter ||= load_front_matter(File.join(root, "_pages", "about.md")) || {}
    end

    def about_body
      @about_body ||= load_body(File.join(root, "_pages", "about.md")) || ""
    end

    def resume
      @resume ||= JSON.parse(File.read(File.join(root, "assets", "json", "resume.json")))
    rescue Errno::ENOENT
      {}
    end

    def projects
      return @projects if @projects

      pattern = File.join(root, "_projects", "*.md")
      files = Dir.glob(pattern).sort
      @projects = files.map do |p|
        fm = load_front_matter(p)
        next nil unless fm
        fm.merge("__source_file" => File.basename(p))
      end.compact
      # Sort primarily by importance (lower = more important), with the
      # filename order as a stable tiebreaker.
      @projects.sort_by! { |p| [(p["importance"] || 99).to_i, p["__source_file"].to_s] }
      @projects
    end

    def repositories
      @repositories ||= YAML.safe_load(File.read(File.join(root, "_data", "repositories.yml"))) || {}
    rescue Errno::ENOENT
      {}
    end

    def socials
      @socials ||= YAML.safe_load(File.read(File.join(root, "_data", "socials.yml"))) || {}
    rescue Errno::ENOENT
      {}
    end

    def bib_entries
      return @bib_entries if @bib_entries

      bib_path = File.join(root, "_bibliography", "papers.bib")
      bib = BibTeX.open(bib_path)
      bib.replace_strings rescue nil
      @bib_entries = bib.select { |e| e.respond_to?(:type) && e.type != :string && e.type != :comment }
      @bib_entries
    end

    # --- Section renderers ------------------------------------------------

    def header
      today = Date.today.strftime("%Y-%m")
      <<~MD.strip
        # #{full_name} — Profile

        > A single-file knowledge base summarizing #{full_name}'s profile, work, projects, publications, patents, and repositories.
        >
        > This document mirrors the content of [#{site_url_label}](#{site_url}) and is intended to be fed to LLMs and AI agents so they can answer questions about #{first_name}'s background, research, and work.
        >
        > Source of truth for the website: <https://github.com/grndnl/grndnl.github.io>
        > Auto-generated: #{today} (do not edit by hand — see scripts/build_agents_md.rb)

        ---
      MD
    end

    def identity_section
      basics = resume["basics"] || {}
      location = basics["location"] || {}
      profiles = basics["profiles"] || []

      lines = ["## Identity & Contact", ""]
      lines << "- **Name:** #{full_name}"

      ipa = extract_ipa(about_front_matter["subtitle"])
      lines << "- **Pronunciation (IPA):** #{ipa}" if ipa

      role = extract_role
      lines << "- **Current role:** #{role}" if role

      summary = basics["summary"]
      lines << "- **Focus areas:** #{summary}" if summary && !summary.strip.empty?

      profile_location = (about_front_matter.dig("profile", "more_info") || "").gsub(%r{</?p>}, "").strip
      city = [location["city"], location["region"]].compact.reject(&:empty?).join(", ")
      loc_str = [profile_location, city].reject { |s| s.nil? || s.empty? }.uniq.join(" | also affiliated with ")
      lines << "- **Location:** #{loc_str}" unless loc_str.empty?

      email = basics["email"] || socials["email"]
      lines << "- **Email:** #{email}" if email

      lines << "- **Website:** <#{site_url}>"

      autodesk = socials["work_url"]
      lines << "- **Autodesk Research profile:** <#{autodesk}>" if autodesk

      profiles.each do |p|
        next if p["url"].nil? || p["url"].empty?
        lines << "- **#{p["network"]}:** <#{p["url"]}>"
      end

      if (li = socials["linkedin_username"])
        url = "https://www.linkedin.com/in/#{li}/"
        lines << "- **LinkedIn:** <#{url}>" unless lines.any? { |l| l.include?(url) }
      end

      if (sch = socials["scholar_userid"])
        url = "https://scholar.google.com/citations?user=#{sch}"
        lines << "- **Google Scholar:** <#{url}>" unless lines.any? { |l| l.include?("scholar.google.com") }
      end

      gh_users = (repositories["github_users"] || []).map { |u| "[#{u}](https://github.com/#{u})" }
      lines << "- **GitHub:** #{gh_users.join(" and ")}" unless gh_users.empty?

      lines.join("\n")
    end

    def about_section
      body = about_body.strip
      return nil if body.empty?

      paragraphs = body.split(/\n{2,}/).reject { |p| p.strip.empty? }
      # Skip paragraphs that look like raw HTML or Liquid blocks (e.g. CTAs
      # injected for the website rendering layer).
      narrative = paragraphs.reject do |p|
        s = p.strip
        s.start_with?("<") || s.start_with?("{%") || s.start_with?("{{")
      end
      return nil if narrative.empty?

      lines = ["## About", ""]
      lines << "_The narrative below is in #{first_name}'s own first-person voice, copied verbatim from the website's about page._"
      lines << ""
      lines.concat(narrative)
      lines.join("\n")
    end

    def education_section
      entries = resume["education"] || []
      return nil if entries.empty?

      lines = ["## Education", "", "| Degree | Institution | Field | Dates |", "|---|---|---|---|"]
      entries.each do |e|
        dates = format_date_range(e["startDate"], e["endDate"])
        lines << "| #{e["studyType"] || ""} | #{e["institution"] || ""} | #{e["area"] || ""} | #{dates} |"
      end
      lines.join("\n")
    end

    def work_section
      entries = resume["work"] || []
      return nil if entries.empty?

      lines = ["## Work Experience", ""]
      entries.each do |e|
        location = clean_inline_html(e["location"])
        dates = format_date_range(e["startDate"], e["endDate"])
        lines << "### #{e["name"]} — #{e["position"]}"
        meta = [location, dates].reject { |s| s.nil? || s.empty? }.join(" · ")
        lines << "*#{meta}*" unless meta.empty?
        lines << ""
        lines << e["summary"].to_s.strip if e["summary"]
        lines << ""
      end
      lines.join("\n").rstrip
    end

    def skills_section
      entries = resume["skills"] || []
      return nil if entries.empty?

      lines = ["## Skills", ""]
      entries.each do |s|
        lines << "- **#{s["name"]}:** #{(s["keywords"] || []).join(", ")}"
      end
      lines.join("\n")
    end

    def projects_section
      return nil if projects.empty?

      lines = ["## Featured Projects", "", "A selection of projects. For the latest research work, see Publications below.", ""]
      projects.each do |p|
        title = clean_emoji_prefix(p["title"].to_s)
        desc = p["description"].to_s.strip
        link = p["redirect"]
        line = "- **#{title}**"
        line += " — #{desc}" unless desc.empty?
        line += " — [Link](#{link})" if link && !link.empty?
        lines << line
      end
      lines.join("\n")
    end

    def repositories_section
      users = repositories["github_users"] || []
      repos = repositories["github_repos"] || []
      return nil if users.empty? && repos.empty?

      lines = ["## GitHub Repositories", ""]
      unless users.empty?
        lines << "GitHub users:"
        lines << ""
        users.each { |u| lines << "- [#{u}](https://github.com/#{u})" }
        lines << ""
      end
      unless repos.empty?
        lines << "Featured repositories:"
        lines << ""
        repos.each { |r| lines << "- [#{r}](https://github.com/#{r})" }
      end
      lines.join("\n")
    end

    def selected_publications_section(pubs_by_year)
      selected = pubs_by_year.values.flatten.select { |e| e[:selected] }
      return nil if selected.empty?

      selected.sort_by! { |e| -e[:year].to_i }
      lines = [
        "## Selected Publications",
        "",
        "Highlighted as \"selected\" on the website. See the full list below or [Google Scholar](https://scholar.google.com/citations?user=X0qp478AAAAJ&hl=en) for the most up-to-date list.",
        ""
      ]
      selected.each { |e| lines << "- #{format_publication_line(e)}" }
      lines.join("\n")
    end

    def full_publications_section(pubs_by_year)
      non_patent = {}
      pubs_by_year.each do |year, entries|
        non = entries.reject { |e| patent?(e) }
        non_patent[year] = non unless non.empty?
      end
      return nil if non_patent.empty?

      lines = ["## Full Publication List", ""]
      non_patent.keys.sort_by { |y| -y.to_i }.each do |year|
        lines << "### #{year}"
        lines << ""
        non_patent[year].each { |e| lines << "- #{format_publication_line(e)}" }
        lines << ""
      end
      lines.join("\n").rstrip
    end

    def patents_section(patents)
      return nil if patents.empty?

      lines = ["## Patents", ""]
      patents.sort_by { |e| -e[:year].to_i }.each do |e|
        note = e[:note].to_s.strip
        date = e[:year].to_s
        title = e[:title]
        authors = format_authors(e[:authors])
        suffix = note.empty? ? "" : " (#{note})"
        lines << "- **#{date}** — *#{title}.* #{authors}#{suffix}"
      end
      lines.join("\n")
    end

    def themes_section
      <<~MD.rstrip
        ## Research Themes & Keywords

        - Data-driven design and design automation
        - Large Language Models (LLMs) for engineering design
        - Vision-Language Models (VLMs) for engineering documentation
        - Graph Neural Networks (GNNs) on CAD assemblies
        - Knowledge graphs for product teardowns and experiential design knowledge
        - Material selection and recommendation systems
        - Generative design and topology optimization
        - Additive manufacturing (polymer and metal)
        - Benchmarks and datasets for engineering AI (e.g., Fusion 360 Gallery, DesignQA, MSEval, RECALL-MM)
        - Agentic AI for requirements elicitation and conceptual design
      MD
    end

    def how_to_use_section
      <<~MD.rstrip
        ## How to use this file

        This file is intentionally written as a single, self-contained Markdown document so it can be:

        1. Placed at the root of the repo as `AGENTS.md` for AI coding/research agents that look for project-level context.
        2. Downloaded from the website and pasted (or attached) into an LLM chat (e.g., ChatGPT, Claude, Gemini) to ask questions like:
           - *"Summarize #{first_name}'s research on LLMs for engineering design."*
           - *"Which papers should I read first to understand his work on material selection?"*
           - *"List #{first_name}'s collaborations with academic institutions."*
           - *"What patents has #{first_name} co-authored, and what are they about?"*

        For the latest publications, always cross-reference [Google Scholar](https://scholar.google.com/citations?user=X0qp478AAAAJ&hl=en).
      MD
    end

    # --- Publication parsing ---------------------------------------------

    def parse_publications
      pubs_by_year = Hash.new { |h, k| h[k] = [] }
      patents = []

      bib_entries.each do |entry|
        e = bib_entry_to_hash(entry)
        next if e[:title].nil? || e[:title].empty?

        if patent?(e)
          patents << e
          pubs_by_year[e[:year]] << e
        else
          pubs_by_year[e[:year]] << e
        end
      end

      [pubs_by_year, patents]
    end

    def bib_entry_to_hash(entry)
      fields = entry.fields
      title = clean_bib_value(fields[:title]&.to_s)
      authors = entry.respond_to?(:author) && entry[:author] ? entry[:author].map(&:to_s) : []
      year = fields[:year]&.to_s

      venue = nil
      if fields[:journal]
        venue = clean_bib_value(fields[:journal].to_s)
        vol = fields[:volume]&.to_s
        num = fields[:number]&.to_s
        pages = fields[:pages]&.to_s
        venue += " #{vol}" if vol && !vol.empty?
        venue += "(#{num})" if num && !num.empty?
        venue += ":#{pages}" if pages && !pages.empty?
      elsif fields[:booktitle]
        venue = clean_bib_value(fields[:booktitle].to_s)
        org = fields[:organization]&.to_s
        venue += " (#{clean_bib_value(org)})" if org && !org.empty?
      elsif fields[:archivePrefix] || fields[:eprint]
        ep = fields[:eprint]&.to_s
        venue = ep ? "arXiv:#{ep}" : "arXiv"
      elsif fields[:publisher]
        venue = clean_bib_value(fields[:publisher].to_s)
      end

      url = fields[:url]&.to_s
      arxiv = fields[:arxiv]&.to_s || fields[:eprint]&.to_s
      doi = fields[:doi]&.to_s
      note = clean_bib_value(fields[:note]&.to_s)
      abbr = fields[:abbr]&.to_s
      selected = fields[:selected]&.to_s == "true"

      {
        key: entry.key.to_s,
        type: entry.type.to_s,
        title: title,
        authors: authors,
        year: year,
        venue: venue,
        url: url,
        arxiv: arxiv,
        doi: doi,
        note: note,
        abbr: abbr,
        selected: selected
      }
    end

    def patent?(entry)
      return true if entry[:abbr] && entry[:abbr].downcase.include?("patent")
      return true if entry[:note] && entry[:note].downcase.include?("patent")
      false
    end

    def format_publication_line(e)
      authors = format_authors(e[:authors])
      title = "**#{e[:title]}**"
      venue = e[:venue].to_s.strip
      year = e[:year]
      tag = e[:abbr] && !e[:abbr].empty? ? " *(#{e[:abbr]})*" : ""
      link = primary_link(e)

      pieces = [title, "—", authors]
      pieces << "*#{venue}*," unless venue.empty?
      pieces << "#{year}." if year
      line = pieces.join(" ").gsub(/, ?\./, ".").gsub(/ +/, " ")
      line += tag
      line += " [link](#{link})" if link
      line
    end

    def primary_link(e)
      return e[:url] if e[:url] && !e[:url].empty?
      return "https://arxiv.org/abs/#{e[:arxiv]}" if e[:arxiv] && !e[:arxiv].empty? && e[:arxiv] !~ /^http/
      return "https://doi.org/#{e[:doi]}" if e[:doi] && !e[:doi].empty?
      nil
    end

    def format_authors(authors)
      return "" if authors.nil? || authors.empty?

      formatted = authors.map { |a| format_author_name(a) }
      max = 6
      if formatted.size > max
        (formatted.first(max) + ["et al."]).join(", ")
      else
        formatted.join(", ")
      end
    end

    # Convert "Last, First Middle" -> "First M. Last" while keeping "and others" -> "et al."
    def format_author_name(name)
      return "et al." if name.strip.downcase == "others"

      if name.include?(",")
        last, rest = name.split(",", 2).map(&:strip)
        first = rest.to_s.strip
        return "#{first} #{last}".strip
      end
      name.strip
    end

    # --- Helpers ----------------------------------------------------------

    def first_name
      "Daniele"
    end

    def full_name
      first = (resume.dig("basics", "name") || "Daniele Grandi").strip
      first.empty? ? "Daniele Grandi" : first
    end

    def site_url
      "https://grndnl.github.io/"
    end

    def site_url_label
      "grndnl.github.io"
    end

    def extract_ipa(subtitle)
      return nil unless subtitle.is_a?(String)
      m = subtitle.match(/\[([^\]]+)\]/)
      return nil unless m
      ipa = m[1]
      m2 = subtitle.match(/<em>\(([^)]+)\)<\/em>/)
      nick = m2 ? " (#{m2[1]})" : ""
      "[#{ipa}]#{nick}"
    end

    def extract_role
      basics = resume.dig("work") || []
      current = basics.find { |w| w["endDate"].nil? || w["endDate"].empty? }
      return nil unless current
      "#{current["position"]}, [#{current["name"]} Research](https://www.research.autodesk.com/)"
    end

    def format_date_range(start_date, end_date)
      ed = end_date.nil? || end_date.to_s.strip.empty? ? "Present" : end_date
      [start_date, ed].compact.join(" – ")
    end

    def clean_inline_html(value)
      return "" if value.nil?
      # Treat <br> as a separator, then collapse adjacent slashes/whitespace
      # introduced by source values like "San Francisco, CA / <br>Remote".
      value.to_s
           .gsub(/<br\s*\/?>/i, " / ")
           .gsub(/<[^>]+>/, "")
           .gsub(%r{\s*/\s*/\s*}, " / ")
           .gsub(/\s+/, " ")
           .strip
    end

    def clean_emoji_prefix(title)
      title.sub(/^\p{Emoji_Presentation}+/, "").strip
    end

    # Strip braces and surrounding LaTeX cruft from BibTeX field values.
    def clean_bib_value(value)
      return "" if value.nil?
      value.to_s.gsub(/[{}]/, "").gsub(/\s+/, " ").strip
    end

    # Read just the YAML front matter from a Markdown file.
    def load_front_matter(path)
      raw = File.read(path)
      return nil unless raw.start_with?("---")
      _, fm, _body = raw.split(/^---\s*$/, 3)
      YAML.safe_load(fm.to_s, permitted_classes: [Date, Time], aliases: true) || {}
    rescue Errno::ENOENT, Psych::SyntaxError
      nil
    end

    # Read just the body (after front matter) of a Markdown file.
    def load_body(path)
      raw = File.read(path)
      if raw.start_with?("---")
        _, _fm, body = raw.split(/^---\s*$/, 3)
        return body.to_s.strip
      end
      raw.strip
    rescue Errno::ENOENT
      nil
    end
  end
end
