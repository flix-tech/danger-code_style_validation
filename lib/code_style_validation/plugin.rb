module Danger
  # This plugin looks for code style violations for
  # added lines on the current MR / PR,
  # and offers inline patches.
  #
  # It uses 'clang-format' and only checks ".h", ".m", ".mm", ".hpp", ".hh",
  # ".cxx", ".cc" and ".cpp" files
  #
  # @example Ensure that added lines does not violate code style
  #
  #          code_style_validation.check
  #
  # @example Ensure that changes don't violate code style, ignoring Pods directory
  #
  #          code_style_validation.check ignore_file_patterns: [/^Pods\//]
  #
  # @see danger/danger
  # @tags code style, validation
  #
  class DangerCodeStyleValidation < Plugin
    VIOLATION_ERROR_MESSAGE = 'Code style violations detected.'.freeze
    
    # Validates the code style of changed & added files using clang-format.
    # Generates Markdown message with respective patches.
    #
    # @return [void]
    def check(config = {})
      ignore_file_patterns = [*config[:ignore_file_patterns]]

      diff = ''
      case danger.scm_provider
      when :github
        diff = github.pr_diff
      when :gitlab
        diff = gitlab.mr_diff
      when :bitbucket_server
        diff = bitbucket_server.pr_diff
      else
        raise 'Unknown SCM Provider'
      end

      changes = get_changes(diff, ignore_file_patterns)
      offending_files, patches = resolve_changes(changes)

      message = ''
      unless offending_files.empty?
        message = 'Code style violations detected in the following files:' + "\n"  
	offending_files.each do |file_name|
	  message += '* `' + file_name + "`\n\n"
        end	
        message += 'Execute one of the following actions and commit again:' + "\n"
        message += '1. Run `clang-format` on the offending files' + "\n"
        message += '2. Apply the suggested patches with `git apply patch`.' + "\n\n"
        message += patches.join(' ')
      end 

      return if message.empty?
      fail VIOLATION_ERROR_MESSAGE
      markdown '### Code Style Check'
      markdown '---'
      markdown message
    end

    private

    def get_changes(diff_str, ignore_file_patterns)
      changes = {}
      line_cursor = 0

      patches = parse_diff(diff_str)

      patches.each do |patch|
        filename_line = ''
        patch.lines.each do |line|
          if line.start_with?('+++ b/')
            filename_line = line
            break
          end
        end

        next if filename_line.empty?

        file_name = filename_line.split('+++ b/').last.chomp

        unless file_name.end_with?('.m', '.h', '.mm', '.hpp', '.hh', '.cxx', '.cc', '.cpp')
          next
        end

        if ignore_file_patterns.any? { |regex| regex.match(file_name) }
          next
        end

        line_cursor = -1

        changed_line_numbers = []
        starting_line_no = 0

        patch.each_line do |line|
          # get hunk lines
          if line.start_with?('@@ ')
            line_numbers_str = line.split('@@ ')[1].split(' @@')[0]

            starting_line_no = line_numbers_str.split('+')[1].split(',')[0]

            # set cursor to 0 to be aware of the real diff file content lines has started
            line_cursor = 0
            next
          end

          unless line_cursor == -1
            if line.start_with?('+')
              changed_line_no = starting_line_no.to_i + line_cursor.to_i
              changed_line_numbers.push(changed_line_no)
            end
            unless line.start_with?('-')
              line_cursor += 1
            end
          end
        end

        changes[file_name] = changed_line_numbers unless changed_line_numbers.empty?
      end

      changes
    end

    def parse_diff(diff)
      diff.encode!('UTF-8', 'UTF-8', :invalid => :replace)
      patches = if danger.scm_provider == :gitlab
                  diff.split("\n---")
                else
                  diff.split("\ndiff --git")
                end
      patches
    end

    def generate_patch(title, content)
      markup_patch = '#### ' + title + "\n"
      markup_patch += "```diff \n" + content + "\n``` \n"
      markup_patch
    end

    def resolve_changes(changes)
      # Parse all patches from diff string

      offending_files = []
      patches = []
      # patches.each do |patch|
      changes.each do |file_name, changed_lines|
        changed_lines_command_array = []

        changed_lines.each do |line_number|
          changed_lines_command_array.push('-lines=' + line_number.to_s + ':' + line_number.to_s)
        end

        changed_lines_command = changed_lines_command_array.join(' ')
        format_command_array = ['clang-format', changed_lines_command, file_name]

        # clang-format command for formatting JUST changed lines
        formatted = `#{format_command_array.join(' ')}`

        formatted_temp_file = Tempfile.new('temp-formatted')
        formatted_temp_file.write(formatted)
        formatted_temp_file.rewind

        diff_command_array = ['diff', '-u', '--label', file_name, file_name, '--label', file_name, formatted_temp_file.path]

        # Generate diff string between formatted and original strings
        diff = `#{diff_command_array.join(' ')}`
        formatted_temp_file.close
        formatted_temp_file.unlink

	# generate arrays with:
	# 1. Name of offending files
	# 2. Suggested patches, in Markdown format
        unless diff.empty?
	  offending_files = [file_name]
	  patches = [generate_patch(file_name, diff)]
        end
      end

      return offending_files, patches
    end
  end
end
