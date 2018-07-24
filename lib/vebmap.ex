defmodule Vebmap.KeyError do
  defexception [:message]

  def exception(key) do
    %Vebmap.KeyError{message: "this vebmap doesn\'t have the key #{key}"}
  end
end

defmodule Vebmap do
  use Bitwise
  @default_limit 2_147_483_647
  @behaviour Access
  @moduledoc """
  Documentation for Vebmap.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Vebmap.hello()
      :world

  """
  defstruct veb: Veb.new(@default_limit), map: Map.new()

  def new(limit, mode \\ :by_max) do
    %Vebmap{veb: Veb.new(limit, mode), map: Map.new()}
  end

  def delete(vebmap, key) do
    %Vebmap{veb: vebmap.veb |> Veb.delete(key), map: vebmap.map |> Map.delete(key)}
  end

  def drop(vebmap, []), do: vebmap
  def drop(vebmap, [head | tail]), do: drop(delete(vebmap, head), tail)

  def equal?(vebmap1, vebmap2), do: Map.equal?(vebmap1.map, vebmap2.map)

  def fetch!(vebmap, key) do
    case fetch(vebmap, key) do
      :error -> raise(Vebmap.KeyError, key)
      {:ok, res} -> res
    end
  end

  def fetch(vebmap, key) do
    Map.fetch(vebmap.map, key)
  end

  def get(vebmap, key, default \\ nil) do
    Map.get(vebmap.map, key, default)
  end

  def get_and_update!(vebmap, key, fun) do
    value = fetch!(vebmap.map, key)

    case fun.(value) do
      {get, update} ->
        {get, %Vebmap{vebmap | map: Map.put(vebmap.map, key, update)}}

      :pop ->
        {value, delete(vebmap, key)}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  def get_and_update(vebmap, key, fun) do
    current = get(vebmap, key)

    case fun.(current) do
      {get, update} ->
        {get, %Vebmap{vebmap | map: Map.put(vebmap.map, key, update)}}

      :pop ->
        {current, delete(vebmap, key)}

      other ->
        raise "the given function must return a two-element tuple or :pop, got: #{inspect(other)}"
    end
  end

  def get_lazy(vebmap, key, fun) when is_function(fun, 0) do
    case fetch(vebmap, key) do
      :error -> fun.()
      value -> value
    end
  end

  def has_key?(vebmap, key) do
    Map.has_key?(vebmap.map, key)
  end

  def keys(vebmap) do
    Map.keys(vebmap.map)
  end

  def merge(vebmap1, vebmap2) do
    map = Map.merge(vebmap1.map, vebmap2.map)

    if vebmap1.veb.log_u >= vebmap2.veb.log_u do
      the_keys = keys(vebmap2)
      %Vebmap{veb: put_keys(vebmap1.veb, the_keys), map: map}
    else
      the_keys = keys(vebmap1)
      %Vebmap{veb: put_keys(vebmap2.veb, the_keys), map: map}
    end
  end

  defp put_keys(veb, []), do: veb
  defp put_keys(veb, [head | tail]), do: put_keys(Veb.insert(veb, head), tail)

  def merge(vebmap1, vebmap2, fun) do
    map = Map.merge(vebmap1.map, vebmap2.map, fun)

    if vebmap1.veb.log_u >= vebmap2.veb.log_u do
      the_keys = keys(vebmap2)
      %Vebmap{veb: put_keys(vebmap1.veb, the_keys), map: map}
    else
      the_keys = keys(vebmap1)
      %Vebmap{veb: put_keys(vebmap2.veb, the_keys), map: map}
    end
  end

  def from_enum(enumerable, limit \\ @default_limit, mode \\ :auto) do
    map = Map.new(enumerable)
    the_keys = Map.keys(map)
    %Vebmap{veb: Veb.from_list(the_keys, limit, mode), map: map}
  end

  def pop(vebmap, key, default \\ nil) do
    {res, map} = Map.pop(vebmap.map, key, default)
    new_vebmap = %Vebmap{veb: Veb.delete(vebmap.veb, key), map: map}
    {res, new_vebmap}
  end

  def pop_lazy(vebmap, key, fun) do
    if has_key?(vebmap, key) do
      pop(vebmap, key)
    else
      fun.()
    end
  end

  def put(vebmap, key, value) do
    if key < 1 <<< vebmap.veb.log_u do
      %Vebmap{veb: Veb.insert(vebmap.veb, key), map: Map.put(vebmap.map, key, value)}
    else
      :error
    end
  end

  def upgrade_capacity(vebmap, new_limit) do
    %Vebmap{veb: vebmap |> keys() |> Veb.from_list(new_limit, :by_max), map: vebmap.map}
  end

  def put_new(vebmap, key, value) do
    if has_key?(vebmap, key) do
      vebmap
    else
      put(vebmap, key, value)
    end
  end

  def put_new_lazy(vebmap, key, fun) do
    if has_key?(vebmap, key) do
      vebmap
    else
      put(vebmap, key, fun.())
    end
  end

  def replace!(vebmap, key, value) do
    if has_key?(vebmap, key) do
      put(vebmap, key, value)
    else
      raise(Vebmap.KeyError, key)
    end
  end

  def split(vebmap, keys, limit \\ @default_limit, mode \\ :auto) do
    {map1, map2} = Map.split(vebmap.map, keys)
    veb1 = map1 |> Map.keys() |> Veb.from_list(limit, mode)
    veb2 = map2 |> Map.keys() |> Veb.from_list(limit, mode)
    {%Vebmap{veb: veb1, map: map1}, %Vebmap{veb: veb2, map: map2}}
  end

  def take(vebmap, keys, limit \\ @default_limit, mode \\ :auto) do
    map = Map.take(vebmap.map, keys)
    %Vebmap{veb: map |> Map.keys() |> Veb.from_list(limit, mode), map: map}
  end

  def update(vebmap, key, initial, fun) do
    if has_key?(vebmap, key) do
      %Vebmap{vebmap | map: Map.update(vebmap.map, key, initial, fun)}
    else
      put(vebmap, key, initial)
    end
  end

  def update!(vebmap, key, fun) do
    if has_key?(vebmap, key) do
      %Vebmap{vebmap | map: Map.update!(vebmap.map, key, fun)}
    else
      raise(Vebmap.KeyError, key)
    end
  end

  def values(vebmap), do: Map.values(vebmap.map)

  def min_key(vebmap), do: Veb.min(vebmap.veb)
  def max_key(vebmap), do: Veb.max(vebmap.veb)
  def capacity?(vebmap), do: 1 <<< vebmap.veb.log_u
  def max_limit?(vebmap), do: capacity?(vebmap) - 1
  def pred_key(vebmap, key), do: Veb.pred(vebmap.veb, key)
  def succ_key(vebmap, key), do: Veb.succ(vebmap.veb, key)

  def to_list(vebmap) do
    vebmap.veb
    |> Veb.to_list()
    |> Enum.map(fn key -> {key, vebmap[key]} end)
  end
  def to_map(vebmap) do
    vebmap.map
  end

  def slice(vebmap, start, nums) do
    veb_list =
      Enum.slice(vebmap.veb, start, nums)
    map =
      veb_list
      |> Enum.map(fn key -> {key, vebmap.map[key]} end)
      |> make_sliced_map(Map.new())
    %Vebmap{veb: Veb.from_list(veb_list, 1 <<< vebmap.veb.log_u, :by_u), map: map}
  end

  defp make_sliced_map([], map), do: map
  defp make_sliced_map([{key, value} | tail], map), do: make_sliced_map(tail, Map.put(map, key, value))
end
defimpl Enumerable,for: Vebmap do
  def count(vebmap) do
    {:ok, Enum.count(vebmap.map)}
  end
  def member?(vebmap, element) do
    {:ok, Enum.member?(vebmap.map, element)}
  end

  def slice(vebmap) do
    {:ok, Enum.count(vebmap), fn (start, nums) -> vebmap |> Vebmap.slice(start, nums) |> Vebmap.to_list() end}
  end

  def reduce(v, acc, fun) do
    reduce_vebmap({v, v.veb.min}, acc, fun)
  end

  defp reduce_vebmap(_, {:halt, acc}, _fun), do: {:halted, acc}
  defp reduce_vebmap({v, cur}, {:suspend, acc}, fun), do: {:suspended, acc, &reduce_vebmap({v, cur}, &1, fun)}
  defp reduce_vebmap({_v, nil}, {:cont, acc}, _fun), do: {:done, acc}
  defp reduce_vebmap({v, cur}, {:cont, acc}, fun), do: reduce_vebmap({v, Veb.succ(v.veb, cur)}, fun.({cur, v.map[cur]}, acc), fun)

end


defimpl Inspect, for: Vebmap do
  def inspect(vebmap, _opt \\ nil) do
    "%Vebmap{capacity = #{Vebmap.capacity?(vebmap)}, elements = " <> Kernel.inspect(Vebmap.to_list(vebmap)) <> "}"
  end

end

