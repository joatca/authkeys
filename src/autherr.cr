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

# this file connects to the LDAP stored in the config object and provides an each_key method to iterate through the keys

module Authkeys

  enum ErrType
    Config;
    Cmdline;
    Net;
    Auth;
    NoUser;
    NoData;
  end
  
  class AuthErr < Exception

    getter errtype
    
    def initialize(msg : String?, @errtype : ErrType)
      super(msg)
    end

  end

end
