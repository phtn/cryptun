defmodule CryptunTest do
  use ExUnit.Case
  doctest Cryptun

  test "greets the world" do
    assert Cryptun.hello() == :world
  end
end
