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

require 'minitest/autorun'
require 'webmock/minitest'
require_relative '../../objects/baza'
require_relative '../../objects/baza/ec2'
require_relative '../test__helper'

# Test for EC2.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2009-2024 Yegor Bugayenko
# License:: MIT
class Baza::EC2Test < Minitest::Test
  def test_run_instance
    WebMock.disable_net_connect!
    ec2 = Baza::EC2.new(
      'STUBSTUBSTUBSTUBSTUB',
      'fakefakefakefakefakefakefakefakefakefake',
      'us-east-1',
      'sg-424242',
      'sn-42424242',
      loog: fake_loog
    )
    fake_aws(
      'DescribeInstances',
      { reservationSet: { item: { instancesSet: { item: { instanceId: 'i-42424242', launchTime: '2024-01-01' } } } } }
    )
    fake_aws('TerminateInstances', {})
    fake_aws('DescribeImages', { imagesSet: { item: { imageId: 'ami-42424242' } } })
    fake_aws('RunInstances', { instancesSet: { item: { instanceId: 'i-42424242' } } })
    i = ec2.run_instance('some-fake-name', "#!/bin/bash\necho test\n")
    assert_equal('i-42424242', i)
  end

  def test_gc_nothing
    WebMock.disable_net_connect!
    ec2 = Baza::EC2.new(
      'STUBSTUBSTUBSTUBSTUB',
      'fakefakefakefakefakefakefakefakefakefake',
      'us-east-1',
      'sg-424242',
      'sn-42424242',
      loog: fake_loog
    )
    fake_aws('DescribeInstances', { reservationSet: {} })
    ec2.gc!
  end

  def test_live_gc
    WebMock.enable_net_connect!
    cfg = fake_live_cfg
    ec2 = Baza::EC2.new(
      cfg['lambda']['key'],
      cfg['lambda']['secret'],
      cfg['lambda']['region'],
      cfg['lambda']['sgroup'],
      cfg['lambda']['subnet'],
      loog: fake_loog
    )
    ec2.gc!
  end
end
