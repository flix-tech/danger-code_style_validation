module Danger
  # This plugin uses code style checker (validator in the following) to look
  # for code style violations in added lines on the current MR / PR, and offers
  # inline patches.
  # The default validator is 'clang-format'. Only Objective-C files, with
  # extensions ".h", ".m", and ".mm" are checked.
  # It is possible to use other validators for other languages, e.g. 'yapf' for Python.
  #
  # @example Ensure that changes do not violate code style in Objective-C files
  #
  #          code_style_validation.check
  #
  # @example Ensure that changes do not violate code style in files with given extensions
  #
  #          code_style_validation.check file_extensions: ['.hpp', '.cpp']
  #
  # @example Ensure that changes do not violate code style in Python files with YAPF
  #
  #          code_style_validation.check validator: 'yapf',
  #                                      file_extensions: ['.py']
  #
  # @example Ensure that changes do not violate code style, ignoring Pods directory
  #
  #          code_style_validation.check ignore_file_patterns: [/^Pods\//]
  #
  # @see danger/danger
  # @tags code style, validation
  #
  class DangerCodeStyleValidation < Plugin
    VIOLATION_ERROR_MESSAGE = 'Code style violations detected.'.freeze

    # Validates the code style of changed & added files using a validator program.
    # Generates Markdown message with respective patches.
    #
    # @return [void]
    def check(config = {})
      defaults = {validator: 'clang-format', file_extensions: ['.h', '.m', '.mm'], ignore_file_patterns: []}
      config = defaults.merge(config)
      validator = *config[:validator]
      file_extensions = [*config[:file_extensions]]
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

      language = 'objective-c'
      if file_extensions.include? '.cpp' then
        language = 'c++'
      elsif file_extensions.include? '.py' then
        language = 'python'
      end
      changes = get_changes(diff, file_extensions, ignore_file_patterns)
      offending_files, patches = resolve_changes(validator, changes)

      message = ''
      unless offending_files.empty?
        message = 'Code style violations detected in the following files:' + "\n"
        offending_files.each do |file_name|
          message += '* `' + file_name + "`\n\n"
        end
        message += 'Execute one of the following actions and commit again:' + "\n"
        message += '1. Run `%s` on the offending files' % validator + "\n"
        message += '2. Apply the suggested patches with `git apply patch`.' + "\n\n"
        offending_file.zip(patches).each do |file_name, patch|
          message += get_markdown(file_name, patch, language)
        end
      end

      return if message.empty?
      fail VIOLATION_ERROR_MESSAGE
      markdown '### Code Style Check'
      markdown '---'
      markdown message
    end

    private

    def get_markdown(file_name, patch, language)
      md = %(
      <details>
        <summary><strong>Patch for</strong> <code>#{file_name}</code><strong>...</strong></summary>

        ```#{language}
        #{patch}
        ```
      </details>\n
      )

      md
    end

    def get_changes(diff_str, file_extensions, ignore_file_patterns)
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

        unless file_name.end_with?(*file_extensions)
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

    def resolve_changes(validator, changes)
      # Parse all patches from diff string

      offending_files = []
      patches = []
      if validator.include? "clang-format"
        # clang-format
        changed_lines_option = "-lines=%s:%s"
      else
        # YAPF
        changed_lines_option = "--lines=%s-%s"
      end
      changes.each do |file_name, changed_lines|
        changed_lines_command_array = []

        changed_lines.each do |line_number|
          changed_lines_command_array.push(changed_lines_option % [line_number.to_s, line_number.to_s])
        end

        changed_lines_command = changed_lines_command_array.join(' ')
        format_command_array = [validator, changed_lines_command, file_name]

        # validator command for formatting JUST changed lines
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
          offending_files.push(file_name)
          patches.push(generate_patch(file_name, diff))
        end
      end

      return offending_files, patches
    end
  end
end
