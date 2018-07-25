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
  Documentation for Vebmap. Vebmap combines the RS-vEB data structure and the map together, providing nearly all of the interfaces in the Map module and supporting the predecessor and successor access. Now it also support the protocols of Collectable, Inspect and Enumerable.
  """

  defstruct veb: Veb.new(@default_limit), map: Map.new()
  @type key :: integer
  @type value :: any
  @type t :: %Vebmap{veb: Veb.t(), map: %{key => value}}
  @compile {:inline,
            fetch: 2,
            fetch!: 2,
            get: 2,
            put: 3,
            delete: 2,
            has_key?: 2,
            replace!: 3,
            capacity: 1,
            max_limit: 1,
            pred_key: 2,
            succ_key: 2}

  @spec new(non_neg_integer, :by_max | :by_u | :by_logu) :: t
  def new(limit, mode \\ :by_max) do
    %Vebmap{veb: Veb.new(limit, mode), map: Map.new()}
  end

  @spec delete(t, key) :: t
  def delete(vebmap, key) do
    %Vebmap{veb: vebmap.veb |> Veb.delete(key), map: vebmap.map |> Map.delete(key)}
  end

  @spec drop(t, [key]) :: t
  def drop(vebmap, []), do: vebmap
  def drop(vebmap, [head | tail]), do: drop(delete(vebmap, head), tail)

  @spec equal?(t, t) :: boolean
  def equal?(vebmap1, vebmap2), do: Map.equal?(vebmap1.map, vebmap2.map)

  @spec fetch!(t, key) :: value | no_return
  def fetch!(vebmap, key) do
    case fetch(vebmap, key) do
      :error -> raise(Vebmap.KeyError, key)
      {:ok, res} -> res
    end
  end

  @spec fetch(t, key) :: {:ok, value} | :error
  def fetch(vebmap, key) do
    Map.fetch(vebmap.map, key)
  end

  @spec get(t, key, value) :: value
  def get(vebmap, key, default \\ nil) do
    Map.get(vebmap.map, key, default)
  end

  @spec get_and_update!(t, key, (value -> {get, value} | :pop)) :: {get, t} | no_return
        when get: term
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

  @spec get_and_update(t, key, (value -> {get, value} | :pop)) :: {t, map} when get: term
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

  @spec get_lazy(t, key, (() -> value)) :: value
  def get_lazy(vebmap, key, fun) when is_function(fun, 0) do
    case fetch(vebmap, key) do
      :error -> fun.()
      value -> value
    end
  end

  @spec has_key?(t, key) :: boolean
  def has_key?(vebmap, key) do
    Map.has_key?(vebmap.map, key)
  end

  @spec keys(t) :: [key]
  def keys(vebmap) do
    Map.keys(vebmap.map)
  end

  @spec merge(t, t) :: t
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

  @spec merge(t, t, (key, value, value -> value)) :: t
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

  @spec from_enum(Enumerable.t(), non_neg_integer, :auto | :by_max | :by_u | :by_logu) :: t
  def from_enum(enumerable, limit \\ @default_limit, mode \\ :auto) do
    map = Map.new(enumerable)
    the_keys = Map.keys(map)
    %Vebmap{veb: Veb.from_list(the_keys, limit, mode), map: map}
  end

  @spec pop(t, key, value) :: {value, t}
  def pop(vebmap, key, default \\ nil) do
    {res, map} = Map.pop(vebmap.map, key, default)
    new_vebmap = %Vebmap{veb: Veb.delete(vebmap.veb, key), map: map}
    {res, new_vebmap}
  end

  @spec pop_lazy(t, key, (() -> value)) :: {value, t}
  def pop_lazy(vebmap, key, fun) do
    if has_key?(vebmap, key) do
      pop(vebmap, key)
    else
      fun.()
    end
  end

  @spec put(t, key, value) :: t | :error
  def put(vebmap, key, value) do
    if key < 1 <<< vebmap.veb.log_u do
      %Vebmap{veb: Veb.insert(vebmap.veb, key), map: Map.put(vebmap.map, key, value)}
    else
      :error
    end
  end

  @spec upgrade_capacity(t, non_neg_integer) :: t | :error
  def upgrade_capacity(vebmap, new_limit) do
    if new_limit >= 1 <<< vebmap.veb.log_u do
      %Vebmap{veb: vebmap |> keys() |> Veb.from_list(new_limit, :by_max), map: vebmap.map}
    else
      :error
    end
  end

  @spec put_new(t, key, value) :: t
  def put_new(vebmap, key, value) do
    if has_key?(vebmap, key) do
      vebmap
    else
      put(vebmap, key, value)
    end
  end

  @spec put_new_lazy(t, key, (() -> value)) :: t
  def put_new_lazy(vebmap, key, fun) do
    if has_key?(vebmap, key) do
      vebmap
    else
      put(vebmap, key, fun.())
    end
  end

  @spec replace(t, key, value) :: t
  def replace(vebmap, key, value) do
    if has_key?(vebmap, key) do
      put(vebmap, key, value)
    else
      vebmap
    end
  end

  @spec replace!(t, key, value) :: t | no_return
  def replace!(vebmap, key, value) do
    if has_key?(vebmap, key) do
      put(vebmap, key, value)
    else
      raise(Vebmap.KeyError, key)
    end
  end

  @spec split(t, [key]) :: t
  def split(vebmap, keys) do
    {map1, map2} = Map.split(vebmap.map, keys)
    veb1 = map1 |> Map.keys() |> Veb.from_list(vebmap.veb.log_u, :by_logu)
    veb2 = map2 |> Map.keys() |> Veb.from_list(vebmap.veb.log_u, :by_logu)
    {%Vebmap{veb: veb1, map: map1}, %Vebmap{veb: veb2, map: map2}}
  end

  @spec take(t, [key]) :: t
  def take(vebmap, keys) do
    map = Map.take(vebmap.map, keys)
    %Vebmap{veb: map |> Map.keys() |> Veb.from_list(vebmap.veb.log_u, :by_logu), map: map}
  end

  @spec update(t, key, value, (value -> value)) :: t
  def update(vebmap, key, initial, fun) do
    if has_key?(vebmap, key) do
      %Vebmap{vebmap | map: Map.update(vebmap.map, key, initial, fun)}
    else
      put(vebmap, key, initial)
    end
  end

  @spec update(t, key, value, (value -> value)) :: t | no_return
  def update!(vebmap, key, fun) do
    if has_key?(vebmap, key) do
      %Vebmap{vebmap | map: Map.update!(vebmap.map, key, fun)}
    else
      raise(Vebmap.KeyError, key)
    end
  end

  @spec values(t) :: [value]
  def values(vebmap), do: Map.values(vebmap.map)

  @spec min_key(t) :: key
  def min_key(vebmap), do: Veb.min(vebmap.veb)

  @spec max_key(t) :: key
  def max_key(vebmap), do: Veb.max(vebmap.veb)

  @spec capacity(t) :: non_neg_integer
  def capacity(vebmap), do: 1 <<< vebmap.veb.log_u

  @spec max_limit(t) :: non_neg_integer
  def max_limit(vebmap), do: capacity(vebmap) - 1

  @spec pred_key(t, key) :: key
  def pred_key(vebmap, key), do: Veb.pred(vebmap.veb, key)

  @spec succ_key(t, key) :: key
  def succ_key(vebmap, key), do: Veb.succ(vebmap.veb, key)

  @spec to_list(t) :: [{key, value}]
  def to_list(vebmap) do
    vebmap.veb
    |> Veb.to_list()
    |> Enum.map(fn key -> {key, vebmap[key]} end)
  end

  @spec to_map(t) :: %{key => value}
  def to_map(vebmap) do
    vebmap.map
  end

  @spec slice(t, non_neg_integer, non_neg_integer) :: t
  def slice(vebmap, start, nums) do
    veb_list = Enum.slice(vebmap.veb, start, nums)

    map =
      veb_list
      |> Enum.map(fn key -> {key, vebmap.map[key]} end)
      |> make_sliced_map(Map.new())

    %Vebmap{veb: Veb.from_list(veb_list, vebmap.veb.log_u, :by_logu), map: map}
  end

  defp make_sliced_map([], map), do: map

  defp make_sliced_map([{key, value} | tail], map),
    do: make_sliced_map(tail, Map.put(map, key, value))
end

defimpl Enumerable, for: Vebmap do
  def count(vebmap) do
    {:ok, Enum.count(vebmap.map)}
  end

  def member?(vebmap, element) do
    {:ok, Enum.member?(vebmap.map, element)}
  end

  def slice(vebmap) do
    {:ok, Enum.count(vebmap),
     fn start, nums -> vebmap |> Vebmap.slice(start, nums) |> Vebmap.to_list() end}
  end

  def reduce(v, acc, fun) do
    reduce_vebmap({v, v.veb.min}, acc, fun)
  end

  defp reduce_vebmap(_, {:halt, acc}, _fun), do: {:halted, acc}

  defp reduce_vebmap({v, cur}, {:suspend, acc}, fun),
    do: {:suspended, acc, &reduce_vebmap({v, cur}, &1, fun)}

  defp reduce_vebmap({_v, nil}, {:cont, acc}, _fun), do: {:done, acc}

  defp reduce_vebmap({v, cur}, {:cont, acc}, fun),
    do: reduce_vebmap({v, Veb.succ(v.veb, cur)}, fun.({cur, v.map[cur]}, acc), fun)
end

defimpl Inspect, for: Vebmap do
  def inspect(vebmap, _opt \\ nil) do
    "%Vebmap{capacity = #{Vebmap.capacity(vebmap)}, elements = " <>
      Kernel.inspect(Vebmap.to_list(vebmap)) <> "}"
  end
end

defimpl Collectable, for: Vebmap do
  def into(original) do
    fun = fn
      vebmap, {:cont, {k, v}} -> Vebmap.put(vebmap, k, v)
      vebmap, :done -> vebmap
      _, :halt -> :ok
    end

    {original, fun}
  end
end
