# The MIT License
#
# Copyright (c) 2005 Thomas Sawyer
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

class OpenHash < Hash

  # New OpenHash.
  def initialize(data={})
    super()
    merge!(data)
  end

  #
  def <<(x)
    case x
      when Hash
        update(x)
      when Array
        x.each_slice(2) do |(k, v)|
          self[k] = v
        end
    end
  end

  #
  def respond_to?(name)
    key?(name.to_sym) || super(name)
  end

  #
  def to_h
    dup
  end

  #
  def to_hash
    dup
  end

  #
  def inspect
    super
  end

  # Omit specific Hash methods from slot protection.
  def omit!(*methods)
    methods.reject!{ |x| x.to_s =~ /^__/ }
    (
    class << self;
      self;
    end).class_eval{ private *methods }
  end

  # Route get and set calls.
  def method_missing(s, *a, &b)
    type = s.to_s[-1, 1]
    name = s.to_s.sub(/[!?=]$/, '')
    key = name.to_sym
    case type
      when '='
        self[key] = a[0]
      #when '!'
      # self[s] = OpenHash.new
      when '?'
        key?(key)
      else
        if key?(key)
          self[key]
        else
          super(s, *a, &b)
        end
    end
  end
end