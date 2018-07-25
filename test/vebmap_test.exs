defmodule VebmapTest do
  use ExUnit.Case
  doctest Vebmap
  @default_range 0..10_000
  defp gen_data(range \\ @default_range) do
    map =
      range
      |> Enum.map(fn i -> {i, i} end)
      |> Map.new()

    {map, Vebmap.from_enum(map)}
  end

  test "enumerable protocol" do
    {map, vebmap} = gen_data()
    assert vebmap |> Enum.reduce(true, fn {k, v}, acc -> k == v && acc end)
    assert vebmap |> Enum.slice(99, 1129) == map |> Enum.sort() |> Enum.slice(99, 1129)

    for(i <- 1..1_000) do
      a = Enum.random(@default_range)
      assert vebmap[i] == map[i]
      assert vebmap[a] == map[a]
    end
  end

  test "map functions" do
    {map, vebmap} = gen_data()

    for(i <- 1..1_000 |> Enum.map(fn _ -> Enum.random(@default_range) end)) do
      assert Vebmap.put(vebmap, i, i)[i] == Map.put(map, i, i)[i]
      drop_list = Stream.repeatedly(fn -> Enum.random(@default_range) end) |> Enum.take(1_000)
      assert Vebmap.drop(vebmap, drop_list).map == Map.drop(map, drop_list)
    end
  end

  defp random_delete(vebmap, 0), do: vebmap

  defp random_delete(vebmap, nums) do
    a = Enum.random(@default_range)
    random_delete(Vebmap.delete(vebmap, a), nums - 1)
  end

  test "test veb functions" do
    {_, vebmap} = gen_data()

    for(i <- 1..1_000 |> Enum.map(fn _ -> Enum.random(@default_range) end)) do
      new_vebmap = random_delete(vebmap, 100)
      assert Vebmap.capacity(new_vebmap) == Vebmap.capacity(vebmap)
      assert Vebmap.pred_key(new_vebmap, i) == Veb.pred(new_vebmap.veb, i)
      assert Vebmap.succ_key(new_vebmap, i) == Veb.succ(new_vebmap.veb, i)
    end
  end
end
