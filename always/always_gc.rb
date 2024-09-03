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

settings.humans.gc.ready_to_expire(settings.expiration_days) do |j|
  j.expire!(settings.fbs)
  settings.loog.debug("Job ##{j.id} is garbage, expired")
end
settings.humans.gc.stuck(60) do |j|
  j.expire!(settings.fbs)
  settings.loog.debug("Job ##{j.id} was stuck, expired")
end
settings.humans.gc.tests(4 * 60) do |j|
  j.expire!(settings.fbs)
  settings.loog.debug("Job ##{j.id} was a test, expired")
end
begin
  tester = settings.humans.his_token(Baza::Tokens::TESTER).human
  tester.durables(settings.fbs).each do |d|
    next if d[:created] > Time.now - (2 * 24 * 60 * 60)
    tester.durables(settings.fbs).get(d[:id]).delete
    settings.loog.debug("Durable ##{d[:id]} was a test, deleted")
  end
rescue Baza::Humans::TokenNotFound
  settings.loog.warn('There is not tester in the system')
end