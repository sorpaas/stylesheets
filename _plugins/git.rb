require 'date'

module Jekyll
  module Filters
    def changed_pages_where(input, property)
      input.select { |object|
        object['changed_pages']
          .select { |page|
          page['page'][property] != nil and page['page'][property] != "" }
          .count > 0 }
    end

    def date_to_xmlschema(input)
      input.xmlschema
    end

    def sort_by_date(input, property)
      input.sort_by { |x|
        x[property] }.reverse
    end
  end

  module GitMetadata
    class Generator < Jekyll::Generator

      safe true

      def generate(site)
        raise "Git is not installed" unless git_installed?

        @site = site
        @first_commits = %x{ git rev-list --max-parents=0 HEAD }.lines.map(&:strip)

        Dir.chdir(site.source) do
          site.config['git'] = site_data
          (site.pages + site.posts.docs).each do |page|
            data = page_data(page.path)
            page.data['git'] = data
            if data and data['commits'] and data['commits'].count > 0
              page.data['updated_at'] = data['commits'].last['commit_date']
              page.data['created_at'] = data['commits'].first['commit_date']
            end
          end
        end

      end

      def site_data
        {
          'project_name' => project_name,
          'files_count' => files_count
        }.merge!(page_data)
      end

      def page_data(relative_path = nil)
        return if relative_path && !tracked_files.include?(relative_path)

        authors = self.authors(relative_path)
        lines = self.lines(relative_path)
        commits = lines.map { |x| commit(x['sha']) }

        commit_day_range = []
        commits.reverse.each do |commit|
          # The first is in the beginninng

          if commit_day_range.count == 0
            commit_day_range = [[commit]]
          else
            start = commit_day_range[0][0]

            if start['commit_date'].to_date === commit['commit_date'].to_date
              commit_day_range[0] = commit_day_range[0] + [ commit ]
            else
              commit_day_range = [[commit]] + commit_day_range
            end
          end
        end

        daily_diff = commit_day_range.each_with_index.map do |range, i|
          diff_end = range.last['sha']
          info = { 'date' => range.first['commit_date'].to_date,
                   'first_commit' => range.last,
                   'last_commit' => range.first }

          if i != commit_day_range.count - 1
            last_diff_end = commit_day_range[i+1].last['sha']

            # puts "Diffing: #{info['date'].to_s}, #{diff_end}, #{last_diff_end}"
            info.merge(diff(diff_end, last_diff_end))
          else
            if range.count == 1
              # puts "Diffing: #{info['date'].to_s}, #{diff_end}, #{diff_end}^"
              info.merge(diff(diff_end))
            else
              diff_start = range.first['sha']
              # puts "Diffing: #{info['date'].to_s}, #{diff_end}, #{diff_start}"
              info.merge(diff(diff_end, diff_start))
            end
          end

        end

        {
          'authors' => authors,
          'total_commits' => authors.inject(0) { |sum, h| sum += h['commits'] },
          'total_additions' => lines.inject(0) { |sum, h| sum += h['additions'] },
          'total_subtractions' => lines.inject(0) { |sum, h| sum += h['subtractions'] },
          'daily_diff' => daily_diff,
          'commits' => commits
        }
      end

      def authors(file = nil)
        cmd = 'git shortlog -se'
        cmd << " -- #{file}" if file
        result = %x{ #{cmd} }
        result.lines.map do |line|
          commits, name, email = line.scan(/(.*)\t(.*)<(.*)>/).first.map(&:strip)
          { 'commits' => commits.to_i, 'name' => name, 'email' => email }
        end
      end

      def lines(file = nil)
        cmd = "git log --numstat --format='%H'"
        cmd << " -- #{file}" if file
        result = %x{ #{cmd} }
        results = result.scan(/(.*)\n\n((?:.*\t.*\t.*\n)*)/)
        results.map do |line|
          files = line[1].scan(/(.*)\t(.*)\t(.*)\n/)
          line[1] = files.inject(0){|s,a| s+=a[0].to_i}
          line[2] = files.inject(0){|s,a| s+=a[1].to_i}
        end
        results.map do |line|
          { 'sha' => line[0], 'additions' => line[1], 'subtractions' => line[2] }
        end
      end

      def diff(sha_end, sha_start=nil)
        if @first_commits.include? sha_end
          diff = %x{ git diff --name-status #{sha_end} }
        elsif sha_start
          diff = %x{ git diff --name-status #{sha_start} #{sha_end}}
        else
          diff = %x{ git diff --name-status #{sha_end}^ #{sha_end}}
        end
        changed_files = diff.lines.map do |line|
          status, file = line.scan(/(.*)\t(.*)/).first.map(&:strip)
          { 'status' => status, 'file' => file }
        end
        changed_pages = changed_files.map do |file|
          page = @site.pages.find do |page|
            page.path == file['file']
          end

          if page
            { 'status' => file['status'], 'page' => page }
          else
            nil
          end
        end.select do |page|
          page != nil
        end

        { 'changed_files' => changed_files,
          'changed_pages' => changed_pages }
      end

      def commit(sha)
        result = %x{ git show --format=fuller -q #{sha} }
        long_sha, author_name, author_email, author_date, commit_name, commit_email, commit_date, message = result
          .scan(/commit (.*)\nAuthor:(.*)<(.*)>\nAuthorDate:(.*)\nCommit:(.*)<(.*)>\nCommitDate:(.*)\n\n(.*)/)
          .first
          .map(&:strip)
        {
          'sha' => long_sha,
          'author_name' => author_name,
          'author_email' => author_email,
          'author_date' => DateTime.parse(author_date),
          'commit_name' => commit_name,
          'commit_email' => commit_email,
          'commit_date' => DateTime.parse(commit_date),
          'message' => message
        }.merge(diff(sha))
      end

      def tracked_files
        @tracked_files ||= %x{ git ls-tree --full-tree -r --name-only HEAD }.split("\n")
      end

      def project_name
        File.basename(%x{ git rev-parse --show-toplevel }.strip)
      end

      def files_count
        %x{ git ls-tree -r HEAD | wc -l }.strip.to_i
      end

      def git_installed?
        null = '/dev/null'
        system "git --version >>#{null} 2>&1"
      end
    end
  end
end
