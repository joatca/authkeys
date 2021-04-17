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

  class KeyReader

    def initialize(@config : Config)
      plain_socket = TCPSocket.new(@config.server, @config.port)
      socket = if @config.simple_tls
                 # in simple TLS mode we bring up a new socket with TLS initialized on the plain socket
                 tls = OpenSSL::SSL::Context::Client.new
                 tls.verify_mode = OpenSSL::SSL::VerifyMode::NONE
                 OpenSSL::SSL::Socket::Client.new(plain_socket, context: tls, sync_close: true, hostname: @config.server)
               else
                 # otherwise we return the plain socket above
                 plain_socket
               end
      tls_context = if @config.start_tls # only true when .simple_tls is false so there's no code path that
                                         # tries to start TLS when it's already up
                      OpenSSL::SSL::Context::Client.new.tap { |s| s.verify_mode = OpenSSL::SSL::VerifyMode::NONE }
                    else
                      nil # either simple TLS or none at all
                    end
      @client = LDAP::Client.new(socket, tls_context)
      @client.authenticate(@config.dn, @config.pw) if @config.need_to_bind? != ""
    end

    def each_key(username : String)
      filter = LDAP::Request::Filter.equal("uid", username)
      filter &= LDAP::Request::FilterParser.parse(@config.filter) if @config.filter != ""
      results = @client.search(base: @config.base, filter: filter)
      # This *should* return an array of zero or one results since uids are supposed to be unique but we make no
      # allowances for the user passing in a username like 'foo*'; here we'll allow for more than one result but
      # we'll only return the keys from the first one. This implies that we really should check for wildcards
      # but since this tool is likely to be called from the sshd config file what's the point?
      #
      # Also, in the case where the query returns no results I've chosen to output nothing at all rather than
      # raise an error. There are conceivably race conditions where a user can log in but for some reason they
      # cannot yet be found at the LDAP URI seen by this code; an error is inappropriate in this case. The SSHD
      # manual doesn't say what happens if the AuthorizedKeysCommand exits non-zero so let's not do that unless
      # something really has exploded.
      if results.size > 0
        (results.first[@config.attrib]? || [] of String).each do |key|
          yield key
        end
      end
    end
    
  end
  
end
