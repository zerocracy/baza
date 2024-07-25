# frozen_string_literal: true

# MIT License
#
# Copyright (c) 2009-2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require_relative '../test__helper'

class Baza::PushJobsTest < Minitest::Test
  def app
    Sinatra::Application
  end

  def test_runs_job
    start_as_tester
    human = tester_human
    tokens = human.tokens
    token_name = fake_name
    token = tokens.add(token_name)
    visit '/push'
    fill_in 'token', with: token.text
    job_name = fake_name
    fill_in 'name', with: job_name
    click_button 'Start'
    assert human.jobs.name_exists?(job_name)
    assert human.jobs.busy?(job_name)
    assert_current_path '/jobs'
  end

  def test_runs_job_with_factbase
    start_as_tester
    human = tester_human
    tokens = human.tokens
    token_name = fake_name
    token = tokens.add(token_name)
    visit '/push'
    fb = Factbase.new
    fb.insert.foo = 'booom \x01\x02\x03'
    Tempfile.open do |f|
      File.binwrite(f.path, fb.export)
      fill_in 'token', with: token.text
      job_name = fake_name
      fill_in 'name', with: job_name
      file = Rack::Test::UploadedFile.new(f.path, 'application/zip')
      attach_file('factbase', file.path)
      click_button 'Start'
      assert human.jobs.name_exists?(job_name)
      assert human.jobs.busy?(job_name)
      assert_current_path '/jobs'
    end
  end

  def test_does_not_run_job_with_invalid_file
    start_as_tester
    human = tester_human
    tokens = human.tokens
    token_name = fake_name
    token = tokens.add(token_name)
    visit '/push'
    Tempfile.open(['tempfile', '.txt']) do |f|
      File.binwrite(f.path, 'Plain text')
      fill_in 'token', with: token.text
      job_name = fake_name
      fill_in 'name', with: job_name
      file = Rack::Test::UploadedFile.new(f.path, 'text/plain')
      attach_file('factbase', file.path)
      click_button 'Start'
      assert !human.jobs.name_exists?(job_name)
      assert_current_path '/dash'
    end
  end

  def test_does_not_run_job_without_token
    start_as_tester
    human = tester_human
    visit '/push'
    fill_in 'token', with: ''
    job_name = fake_name
    fill_in 'name', with: job_name
    click_button 'Start'
    assert !human.jobs.name_exists?(job_name)
    assert !human.jobs.busy?(job_name)
    assert_current_path '/dash'
  end

  def test_does_not_run_job_with_non_existent_token
    start_as_tester
    human = tester_human
    visit '/push'
    fill_in 'token', with: fake_name
    job_name = fake_name
    fill_in 'name', with: job_name
    click_button 'Start'
    assert !human.jobs.name_exists?(job_name)
    assert !human.jobs.busy?(job_name)
    assert_current_path '/dash'
  end

  def test_does_not_run_job_without_name
    start_as_tester
    human = tester_human
    tokens = human.tokens
    token_name = fake_name
    token = tokens.add(token_name)
    visit '/push'
    fill_in 'token', with: token.text
    fill_in 'name', with: ''
    click_button 'Start'
    assert_current_path '/dash'
  end

  def test_does_not_run_job_with_invalid_name
    start_as_tester
    human = tester_human
    tokens = human.tokens
    token_name = fake_name
    token = tokens.add(token_name)
    visit '/push'
    fill_in 'token', with: token.text
    fill_in 'name', with: 'test_job'
    click_button 'Start'
    assert_current_path '/dash'
  end

  def test_does_not_run_busy_job
    start_as_tester
    human = tester_human
    tokens = human.tokens
    token_name = fake_name
    token = tokens.add(token_name)
    visit '/push'
    fill_in 'token', with: token.text
    job_name = fake_name
    fill_in 'name', with: job_name
    click_button 'Start'
    assert human.jobs.name_exists?(job_name)
    assert human.jobs.busy?(job_name)
    assert_current_path '/jobs'

    visit '/push'
    fill_in 'token', with: token.text
    fill_in 'name', with: job_name
    click_button 'Start'
    assert_current_path '/dash'
  end
end
