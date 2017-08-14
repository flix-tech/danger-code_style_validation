require File.expand_path('../spec_helper', __FILE__)

module Danger
  describe Danger::DangerCodeStyleValidation do
    it 'should be a plugin' do
      expect(Danger::DangerCodeStyleValidation.new(nil)).to be_a Danger::Plugin
    end

    describe 'with Dangerfile' do
      before do
        @dangerfile = testing_dangerfile
        @my_plugin = @dangerfile.code_style_validation
      end

      it 'Reports code style violation as error' do
        diff = File.read('spec/fixtures/violated_diff.diff')
        expected_message = File.read('spec/fixtures/violated_diff_message.md')

        allow(@my_plugin.github).to receive(:pr_diff).and_return diff
        @my_plugin.check file_extensions: ['.h', '.m', '.mm', '.cpp']

        expect(@dangerfile.status_report[:errors]).to eq([DangerCodeStyleValidation::VIOLATION_ERROR_MESSAGE])
        expect(@dangerfile.status_report[:markdowns].map(&:message).join("\n")).to eq(expected_message)
      end

      it 'Does not report error when extension is excluded' do
        diff = File.read('spec/fixtures/violated_diff.diff')

        allow(@my_plugin.github).to receive(:pr_diff).and_return diff
        @my_plugin.check file_extensions: ['.h', '.c']

        expect(@dangerfile.status_report[:errors]).to eq([])
      end

      it 'Does not report error when code not violated' do
        diff = File.read('spec/fixtures/innocent_diff.diff')

        allow(@my_plugin.github).to receive(:pr_diff).and_return diff
        @my_plugin.check

        expect(@dangerfile.status_report[:errors]).to eq([])
      end

      it 'Does not report error for different extension types of files' do
        diff = File.read('spec/fixtures/ruby_diff.diff')

        allow(@my_plugin.github).to receive(:pr_diff).and_return diff
        @my_plugin.check

        expect(@dangerfile.status_report[:errors]).to eq([])
      end

      it 'Does not report unexpected errors when there are only removals in the diff' do
        diff = File.read('spec/fixtures/red_diff.diff')

        allow(@my_plugin.github).to receive(:pr_diff).and_return diff
        @my_plugin.check

        expect(@dangerfile.status_report[:errors]).to eq([])
      end

      it 'Ignores files matching ignored patterns' do
        diff = File.read('spec/fixtures/violated_diff.diff')

        allow(@my_plugin.github).to receive(:pr_diff).and_return diff
        @my_plugin.check file_extensions: ['.h', '.m'],
                         ignore_file_patterns: [%r{^spec/}]

        expect(@dangerfile.status_report[:errors]).to eq([])
      end

      it 'Allows single pattern instead of array' do
        diff = File.read('spec/fixtures/violated_diff.diff')

        allow(@my_plugin.github).to receive(:pr_diff).and_return diff
        @my_plugin.check ignore_file_patterns: %r{^spec/}

        expect(@dangerfile.status_report[:errors]).to eq([])
      end

      it 'Allows single file extension instead of array' do
        diff = File.read('spec/fixtures/violated_diff.diff')

        allow(@my_plugin.github).to receive(:pr_diff).and_return diff
        @my_plugin.check file_extensions: '.m'

        expect(@dangerfile.status_report[:errors]).to eq([DangerCodeStyleValidation::VIOLATION_ERROR_MESSAGE])
      end
    end
  end
end
