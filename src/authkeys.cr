# This file is part of authkeys, a tool intended to be used as an AuthorizedKeysCommand for sshd
#
# Copyright Fraser McCrossan <fraser@mccrossan.ca> 2021
# 
# ne is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ne is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with authkeys.  If not, see <http://www.gnu.org/licenses/>.

require "ldap"
require "./config"
require "./key_reader"

module Authkeys
  VERSION = "0.1.0"

  begin
    conf = Config.new # this parses both the command line arguments and the sssd config file
    raise "need exactly one username" unless ARGV.size == 1
    reader = KeyReader.new(conf)
    reader.each_key(ARGV.first) do |key|
      puts key
    end
  rescue e : Exception
    # a better option (since we don't know what sshd might do if an AuthorizedKeysCommand fails) is to log this
    # error to syslog then exit gracefully but that is outside the scope of the challenge
    STDERR.puts "#{PROGRAM_NAME}: #{e.message}"
    exit 1
  end
  
end
