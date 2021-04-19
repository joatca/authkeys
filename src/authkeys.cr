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
require "syslog"
require "./config"
require "./key_reader"
require "./autherr"

module Authkeys
  VERSION = "0.1.0"

  begin
    conf = Config.new # this parses both the command line arguments and the sssd config file
    raise AuthErr.new("need exactly one username", ErrType::Cmdline) unless ARGV.size == 1
    begin
      reader = KeyReader.new(conf)
      reader.each_key(ARGV.first) do |key|
        puts key
      end
    rescue e : LDAP::Client::AuthError | Socket::Error
      raise AuthErr.new(e.message, ErrType::Net)
    end
  rescue e : AuthErr
    case e.errtype
    when ErrType::Config
      Syslog.error("config file error: #{e.message}")
    when ErrType::Cmdline
      Syslog.error("bad option: #{e.message}")
    when ErrType::Net
      Syslog.critical("unable to connect: #{e.message}")
    when ErrType::Auth
      Syslog.error("LDAP login problem: #{e.message}")
    when ErrType::NoUser
      Syslog.warning("user not found: #{e.message}")
    when ErrType::NoData
      Syslog.info("no keys for user: #{e.message}")
    end
  rescue e : Exception
    Syslog.critical("unhandled exception #{e.class}: #{e.message}")
  end
  
end
