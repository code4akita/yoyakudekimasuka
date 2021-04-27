class ProxyObject
  attr_reader :proxy

  def initialize proxy
    @proxy = proxy
  end

  def method_missing name, *args
    proxy.send name, *args
  end

end
