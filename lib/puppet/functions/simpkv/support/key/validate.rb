# Validates key conforms to the simpkv key specification
#
# * simpkv key specification
#
#   * Key must contain only the following characters:
#
#     * a-z
#     * A-Z
#     * 0-9
#     * The following special characters: `._:-/`
#
#   * Key may not contain '/./' or '/../' sequences.
#
# * Terminates catalog compilation if validation fails.
#
# @author https://github.com/simp/pupmod-simp-simpkv/graphs/contributors
#
Puppet::Functions.create_function(:'simpkv::support::key::validate') do

  # @param key simpkv key
  #
  # @return [Nil]
  # @raise ArgumentError if validation fails
  #
  # @example Passing
  #   simpkv::support::key::validate('looks/like/a/file/path')
  #   simpkv::support::key::validate('looks/like/a/directory/path/')
  #   simpkv::support::key::validate('simp-simp_snmpd:password.auth')
  #
  # @example Failing
  #   simpkv::support::key::validate('${special}/chars/not/allowed!'}
  #   simpkv::support::key::validate('looks/like/an/./unexpanded/linux/path')
  #   simpkv::support::key::validate('looks/like/another/../unexpanded/linux/path')
  #
  dispatch :validate do
    param 'String[1]', :key
  end

  def validate(key)
    ws_regex = /[[:space:]]/
    if (key =~ ws_regex)
      msg = "key '#{key}' contains disallowed whitespace"
      raise ArgumentError.new(msg)
    end

    char_regex = /^[a-zA-Z0-9._:\-\/]+$/m
    unless (key =~ char_regex)
      msg = "key '#{key}' contains unsupported characters.  Allowed set=[a-zA-Z0-9._:-/]"
      raise ArgumentError.new(msg)
    end

    dot_regex = /\/\.\.?\//
    if (key =~ dot_regex)
      msg = "key '#{key}' contains disallowed '/./' or '/../' sequence"
      raise ArgumentError.new(msg)
    end
  end

end

