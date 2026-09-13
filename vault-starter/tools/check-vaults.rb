#!/usr/bin/env ruby
# Read-only structural audit for a Context OS. Run from anywhere:
#   ruby tools/check-vaults.rb [--json | --self-test]
# A vault is any top-level folder with a CLAUDE.md whose name does not start with "_" or ".".
require 'yaml'
require 'date'
require 'json'
require 'pathname'
require 'uri'

EXCLUDED = %w[raw _archive Templates Attachments attachments tools tests data .obsidian .git node_modules].freeze

def vaults(root)
  root.children.select { |d| d.directory? && d.join('CLAUDE.md').file? && !d.basename.to_s.start_with?('_', '.') }
      .map { |d| d.basename.to_s }.sort
end

def document(text)
  match = text.match(/\A---\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|\z)(.*)\z/m)
  raise ArgumentError, 'missing or unclosed frontmatter' unless match
  mapping = YAML.parse(match[1]).root
  raise ArgumentError, 'frontmatter must be a mapping' unless mapping.is_a?(Psych::Nodes::Mapping)
  keys = mapping.children.each_slice(2).map { |key, _| key.value }
  raise ArgumentError, 'duplicate frontmatter key' unless keys.uniq == keys
  metadata = YAML.safe_load(match[1], permitted_classes: [Date, Time], aliases: false)
  [metadata, match[2]]
end

def prose(body)
  body.gsub(/^```.*?^```[^\n]*$/m, '').gsub(/`[^`\n]*`/, '')
end

def iso(value)
  Date.iso8601(value.is_a?(Time) ? value.to_date.iso8601 : value.to_s)
end

def audit(root)
  all = vaults(root)
  errors, attention, documents = [], [], {}
  files = all.flat_map { |v| Dir.glob(root.join(v, '**', '*').to_s) }.select { |f| File.file?(f) }
  names = Hash.new { |h, k| h[k] = [] }
  files.each do |file|
    path = Pathname(file).relative_path_from(root)
    vault, *parts = path.each_filename.to_a
    next if parts.any? { |part| %w[tools tests node_modules .obsidian].include?(part) }
    parts.each_index.map { |i| parts[i..-1].join('/') }.flat_map { |n| [n, n.sub(/\.md\z/i, '')] }.each do |key|
      names[[vault, key.downcase]] << path.to_s
    end
    next unless file.end_with?('.md') && parts.first == 'wiki'
    next if file.end_with?('.excalidraw.md') || File.zero?(file)
    next if path.each_filename.any? { |part| EXCLUDED.include?(part) }
    begin
      metadata, body = document(File.read(file))
      documents[path.to_s] = [metadata, body]
      %w[created updated].each { |key| attention << "#{path}: #{key} missing" if metadata[key].nil? }
      %w[created updated as_of review_after].each { |key| iso(metadata[key]) unless metadata[key].nil? }
      raise ArgumentError, 'tags must be a list when present' unless metadata['tags'].nil? || metadata['tags'].is_a?(Array)
      Array(metadata['aliases']).each { |name| names[[vault, name.to_s.downcase]] << path.to_s }
      if metadata['review_after'] && iso(metadata['review_after']) < Date.today &&
         !%w[archived completed done superseded].include?(metadata['status'])
        attention << "#{path}: review_after passed (re-check, not proof the fact changed)"
      end
    rescue Psych::Exception, ArgumentError, Date::Error => e
      errors << "#{path}: #{e.message.lines.first.strip}"
    end
  end
  # OS checks: the root routing table must match the folders on disk, and stay small (it loads every session).
  root_md = root.join('CLAUDE.md')
  if root_md.file?
    text = root_md.read
    routed = text.scan(/^\|\s*`?([\w.-]+)\/?`?\s*\|/).flatten.reject { |v| v == 'Vault' || v.match?(/\A[-:]+\z/) }
    (routed - all).each { |v| errors << "CLAUDE.md: routes to vault '#{v}' but no #{v}/CLAUDE.md exists" }
    (all - routed).each { |v| attention << "CLAUDE.md: vault '#{v}' exists but is missing from the routing table" }
    attention << "CLAUDE.md: #{text.lines.size} lines; keep the always-loaded root short (<200)" if text.lines.size > 200
  end
  all.each do |vault|
    %w[wiki/index.md wiki/log.md].each { |f| errors << "#{vault}/#{f}: missing" unless root.join(vault, f).file? }
    index = root.join(vault, 'wiki', 'index.md')
    if index.file?
      listed = index.read.scan(/\[\[([^\]|#]+)/).flatten.map { |l| File.basename(l.strip).downcase }
      Dir.glob(root.join(vault, 'wiki', '*.md').to_s).map { |f| File.basename(f, '.md') }
         .reject { |n| %w[index log].include?(n.downcase) || listed.include?(n.downcase) }
         .each { |n| attention << "#{vault}/wiki/#{n}.md: not listed in index.md" }
    end
    adapter = root.join(vault, 'AGENTS.md')
    unless adapter.symlink? && adapter.file? && adapter.realpath == root.join(vault, 'CLAUDE.md').realpath
      attention << "#{vault}/AGENTS.md: should be a symlink to CLAUDE.md (Codex reads AGENTS.md)"
    end
  end
  resolve = lambda do |path, target|
    vault = path.split('/').first
    bases = [root.join(path).dirname, root.join(vault), root.join(vault, 'wiki')]
    found = []
    bases.each do |base|
      found = [base.join(target), base.join(target + '.md')].select { |p| p.file? && p.cleanpath.to_s.start_with?(root.join(vault).to_s + '/') }
      break unless found.empty?
    end
    found.empty? ? names[[vault, target.downcase]].uniq : found.map(&:to_s).uniq
  end
  missing, cross_vault, ambiguous = [], [], []
  documents.each do |path, (_, body)|
    prose(body).scan(/\[\[([^\]]+)\]\]/).flatten.each do |link|
      target = link.split('|', 2).first.split('#', 2).first.to_s.strip
      next if target.empty?
      local = resolve.call(path, target)
      if local.empty?
        elsewhere = all.reject { |v| v == path.split('/').first }.flat_map { |v| names[[v, target.downcase]] }.uniq
        (elsewhere.empty? ? missing : cross_vault) << "#{path}: [[#{link}]]"
      elsif local.size > 1 && !target.include?('/')
        ambiguous << "#{path}: [[#{link}]]"
      end
    end
    next unless File.basename(path) == 'index.md'
    prose(body).scan(/(?<!!)\[[^\]]+\]\(([^)]+)\)/).flatten.each do |link|
      target = URI::DEFAULT_PARSER.unescape(link.delete_prefix('<').delete_suffix('>')).split('#', 2).first.to_s
      next if target.empty? || target.match?(/\A(?:[a-z]+:|\/)/i)
      errors << "#{path}: broken relative index link #{link}" unless root.join(path).dirname.join(target).file?
    end
  end
  # ponytail: title/path resolution only, not Obsidian's renderer; block/heading anchors need manual checks.
  { vaults: all, pages: documents.size,
    pages_by_vault: documents.keys.group_by { |p| p.split('/').first }.transform_values(&:size),
    errors: errors, attention: attention,
    unresolved_wikilinks: missing.uniq, cross_vault_wikilinks: cross_vault.uniq, ambiguous_wikilinks: ambiguous.uniq }
end

if ARGV.include?('--self-test')
  metadata, body = document("---\ntags: [note]\nupdated: 2026-09-04\n---\n# Kept\n")
  raise 'valid document rejected' unless metadata['tags'] == ['note'] && body == "# Kept\n"
  ["---\ntags: [note]\n# No close", "---\nstatus: active\nstatus: done\n---\n", "---\ntags: [\n---\n"].each do |bad|
    begin
      document(bad)
    rescue Psych::Exception, ArgumentError
      next
    end
    raise 'invalid document accepted'
  end
  raise 'code examples counted as links' if prose("```md\n[[example]]\n```\n`[[literal]]`\n").include?('[[')
  require 'tmpdir'
  Dir.mktmpdir do |dir|
    root = Pathname(dir)
    root.join('me', 'wiki').mkpath
    root.join('_vault-template', 'wiki').mkpath
    root.join('me', 'CLAUDE.md').write("# me\n")
    root.join('_vault-template', 'CLAUDE.md').write("# template\n")
    File.symlink('CLAUDE.md', root.join('me', 'AGENTS.md').to_s)
    root.join('me', 'wiki', 'index.md').write("---\ntags: [index]\ncreated: 2026-01-01\nupdated: 2026-01-01\n---\n- [[Bio]]\n- [[Ghost]]\n")
    root.join('me', 'wiki', 'log.md').write("---\ntags: [log]\ncreated: 2026-01-01\nupdated: 2026-01-01\n---\n")
    root.join('me', 'wiki', 'Bio.md').write("---\ntags: [identity]\ncreated: 2026-01-01\nupdated: 2026-01-01\nreview_after: 2000-01-01\n---\n# Bio\n")
    r = audit(root)
    raise 'template counted as vault' unless r[:vaults] == ['me']
    raise 'clean vault reported errors' unless r[:errors].empty?
    raise 'missing link not found' unless r[:unresolved_wikilinks] == ['me/wiki/index.md: [[Ghost]]']
    raise 'passed review date not flagged' unless r[:attention].any? { |a| a.include?('review_after passed') }
    root.join('CLAUDE.md').write("| Vault | Domain |\n|---|---|\n| `me` | identity |\n| `ghost` | missing |\n")
    root.join('me', 'wiki', 'Orphan.md').write("---\ntags: [x]\ncreated: 2026-01-01\nupdated: 2026-01-01\n---\n")
    r = audit(root)
    raise 'table separator read as a vault' if r[:errors].any? { |e| e.include?("'---'") }
    raise 'phantom route not caught' unless r[:errors].include?("CLAUDE.md: routes to vault 'ghost' but no ghost/CLAUDE.md exists")
    raise 'index drift not caught' unless r[:attention].include?('me/wiki/Orphan.md: not listed in index.md')
    raise 'listed page flagged' if r[:attention].any? { |a| a.include?('Bio.md: not listed') }
  end
  puts 'Self-check passed: frontmatter parsing, code examples, vault discovery, links, review dates, routing table, index drift.'
else
  result = audit(Pathname(__dir__).parent.realpath)
  if ARGV.include?('--json')
    puts JSON.pretty_generate(result)
  else
    puts "#{result[:vaults].size} vaults, #{result[:pages]} pages; #{result[:errors].size} structural errors; #{result[:attention].size} notices."
    puts result[:errors]
    puts result[:attention]
    puts "Links needing review: #{result[:unresolved_wikilinks].size} unresolved, #{result[:cross_vault_wikilinks].size} cross-vault, #{result[:ambiguous_wikilinks].size} ambiguous. Use --json for paths."
  end
  exit(result[:errors].empty? ? 0 : 1)
end
