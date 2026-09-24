#!/usr/bin/env ruby
# Files the coordinator's outbox on matz/spinel. Run from the cloud-triage
# worktree: `ruby tools/ship.rb` (once) or `ruby tools/ship.rb --loop`.
require "open3"
require "fileutils"

FORK = "https://github.com/elektronaut/spinel.git"
CHANNEL = "cloud-bug-triage"
UPSTREAM = "matz/spinel"
ROOT = File.expand_path("..", __dir__)
SHIP_WT = File.expand_path("../ship", ROOT)
GIT_AUTH = ["-c", "credential.helper=", "-c", "credential.helper=!gh auth git-credential"]

def run(*cmd, chdir: ROOT)
  out, err, st = Open3.capture3(*cmd, chdir: chdir)
  raise "#{cmd.join(' ')} failed: #{err.strip}" unless st.success?
  out.strip
end

def git(*args, chdir: ROOT) = run("git", *GIT_AUTH, *args, chdir: chdir)

def log(msg)
  line = "#{Time.now.strftime('%H:%M')} #{msg}"
  puts line
  File.open(File.join(ROOT, "outbox/filed.md"), "a") { |f| f.puts "- #{line}" }
end

def parse(path)
  text = File.read(path)
  _, front, body = text.split(/^---\s*$/, 3)
  meta = front.lines.to_h { |l| k, v = l.split(":", 2); [k.strip, v.to_s.strip] }
  [meta, body.to_s.strip + "\n"]
end

def filed
  path = File.join(ROOT, "outbox/filed.md")
  return {} unless File.exist?(path)
  File.read(path).scan(/issue:(\w+) = #(\d+)/).to_h
end

def resolve(text, map)
  text.gsub(/\{\{issue:(\w+)\}\}/) { map.fetch($1) { raise "issue #{$1} not filed yet" }.then { |n| "##{n}" } }
end

def gh_with_body(args, body)
  out, err, st = Open3.capture3("gh", *args, "-F", "-", stdin_data: body, chdir: ROOT)
  raise "gh #{args.first(2).join(' ')} failed: #{err.strip}" unless st.success?
  out.strip
end

def ship_pr(meta, body, map)
  branch = meta.fetch("head")
  git("fetch", FORK, "#{branch}:refs/remotes/ship/#{branch}", "--force")
  old = git("rev-parse", "refs/remotes/ship/#{branch}")
  unless Dir.exist?(SHIP_WT)
    git("worktree", "add", "--detach", SHIP_WT, old)
  end
  git("checkout", "-q", "--detach", old, chdir: SHIP_WT)
  msg = git("log", "-1", "--format=%B", chdir: SHIP_WT)
  if msg.include?("{{issue:")
    File.write("/tmp/ship-msg.txt", resolve(msg, map) + "\n")
    git("commit", "-q", "--amend", "-F", "/tmp/ship-msg.txt", chdir: SHIP_WT)
    git("push", "-q", "--force-with-lease=#{branch}:#{old}", FORK, "HEAD:#{branch}", chdir: SHIP_WT)
  end
  gh_with_body(["pr", "create", "-R", UPSTREAM, "-H", "elektronaut:#{branch}", "-B", "master",
                "-t", meta.fetch("title")], resolve(body, map))
end

def ship_reply(meta, body)
  gh_with_body(["api", "repos/#{UPSTREAM}/pulls/#{meta.fetch('pr')}/comments/#{meta.fetch('comment_id')}/replies",
                "-f", "body=#{body}", "--jq", ".html_url"], "")
end

def once
  git("pull", "-q", "--rebase", FORK, CHANNEL)
  items = Dir[File.join(ROOT, "outbox/[0-9]*.md")].sort
  return if items.empty?
  map = filed
  items.each do |path|
    meta, body = parse(path)
    name = File.basename(path, ".md")
    case meta["kind"]
    when "issue"
      url = gh_with_body(["issue", "create", "-R", UPSTREAM, "-t", meta.fetch("title")], body)
      map[meta.fetch("id")] = url[/\d+\z/]
      log("#{name}: issue:#{meta['id']} = ##{map[meta['id']]} #{url}")
    when "pr"
      url = ship_pr(meta, body, map)
      log("#{name}: pr #{meta['head']} = ##{url[/\d+\z/]} #{url}")
    when "reply"
      url = ship_reply(meta, body)
      log("#{name}: reply on ##{meta['pr']} #{url}")
    else
      log("#{name}: unknown kind #{meta['kind'].inspect}, skipped")
      next
    end
    FileUtils.rm(path)
  rescue => e
    log("#{name}: FAILED #{e.message}")
    break
  end
  git("add", "-A", "outbox")
  git("commit", "-q", "-m", "ship: outbox filed")
  git("pull", "-q", "--rebase", FORK, CHANNEL)
  git("push", "-q", FORK, "HEAD:#{CHANNEL}")
end

if ARGV.include?("--loop")
  loop do
    begin
      once
    rescue => e
      puts "#{Time.now.strftime('%H:%M')} error: #{e.message}"
    end
    sleep 120
  end
else
  once
end
