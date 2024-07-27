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

require 'iri'
require 'always'
require 'loog'
require 'telepost'
require 'decoor'
require 'securerandom'

# Telegram Bot.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::Tbot
  # Fake tbot.
  class Fake
    def initialize(loog = Loog::NULL)
      @loog = loog
    end

    def notify(human, *msg)
      @loog.debug("Notified @#{human.github}: #{msg.join(' ')}")
    end
  end

  # Fake spy.
  class Spy
    def initialize(tbot, chat)
      @tbot = tbot
      @chat = chat
    end

    decoor :tbot

    def to_s
      @tbot.to_s
    end

    def notify(human, *msg)
      unless ENV['RACK_ENV'] == 'test' || human.github == 'yegor256'
        @tbot.notify(human.humans.find('yegor256'), ["To `@#{human.github}`:"] + msg)
      end
      @tbot.notify(human, *msg)
    end
  end

  def initialize(pgsql, token, loog: Loog::NULL)
    @pgsql = pgsql
    @tp = token.empty? ? Telepost::Fake.new : Telepost.new(token)
    @loog = loog
    @always = Always.new(1).on_error { |e, _| @loog.error(Backtrace.new(e)) }
  end

  def to_s
    @always.to_s
  end

  def backtraces
    @always.backtraces
  end

  def start
    @always.start do
      @tp.run do |_client, message|
        chat = message.chat.id
        @loog.debug("TG incoming message in chat ##{chat}: #{message.inspect}")
        entry(chat)
      end
    end
  end

  # Reply to the user in the chat and return user's secret.
  # @return [String] Secret to use in web auth
  def entry(chat)
    if @pgsql.exec('SELECT id FROM telechat WHERE id = $1', [chat]).empty?
      @pgsql.exec(
        'INSERT INTO telechat (id, secret) VALUES ($1, $2)',
        [chat, SecureRandom.uuid]
      )
    end
    row = @pgsql.exec(
      [
        'SELECT human.id, human.github, telechat.secret FROM telechat',
        'LEFT JOIN human ON human.id = telechat.human',
        'WHERE telechat.id = $1'
      ],
      [chat]
    )[0]
    if row['id'].nil?
      auth = Iri.new('https://www.zerocracy.com')
        .append('tauth')
        .add(secret: row['secret'])
      @tp.post(
        chat,
        '🐶 I\'m sorry, I don\'t know you as of yet. Please',
        "[click here](#{auth})",
        "in order to authenticate this chat (ID: `#{chat}`)."
      )
      @loog.debug("Invited user to authenticate, in TG chat ##{chat}")
    else
      @tp.post(
        chat,
        '😸 Hey, I know that you are',
        "[@#{row['github']}](https://github.com/#{row['github']})!",
        "In this chat (ID: `#{chat}`), you will get updates from me when something interesting",
        'happens in your account at [zerocracy.com](https://www.zerocracy.com).'
      )
      @loog.debug("Greeted user @#{row['github']} in TG chat ##{chat}")
    end
    row['secret']
  end

  def notify(human, *lines)
    row = @pgsql.exec('SELECT id FROM telechat WHERE human = $1', [human.id])[0]
    return if row.nil?
    chat = row['id'].to_i
    msg = lines.join(' ')
    msg.gsub!(%r{([a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+)#([0-9]+)}) do |s|
      "[#{s}](https://github.com/#{Regexp.last_match[1]}/issues/#{Regexp.last_match[2]})"
    end
    @tp.post(chat, msg)
  end

  # Authentical the user and return his chat ID in Telegram.
  # @return [Integer] Chat ID in TG
  def auth(human, secret)
    unless @pgsql.exec('SELECT id FROM telechat WHERE human = $1', [human.id]).empty?
      raise Baza::Urror, 'Most probably you are already using another Telegram chat'
    end
    rows = @pgsql.exec('UPDATE telechat SET human = $1 WHERE secret = $2 RETURNING id', [human.id, secret])
    raise Baza::Urror, 'There is no user by this authentication code' if rows.empty?
    human.notify(
      "🍉 Now I know that you are `@#{human.github}`!",
      'Thanks for authorizing your account.',
      'Now, you will receive all important notifications here.'
    )
    rows.first['id'].to_i
  end
end
