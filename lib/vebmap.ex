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

  To get the size of a vebmap, please use `Enum.count/1`:

      iex> [{0, 0}, {1, 1}, {2, 2}] |> Vebmap.from_enum() |> Enum.count()
      3

  Here is an example of how a vebmap is inspected:

      iex> [{0, 0}, {1, 1}, {2, 2}] |> Vebmap.from_enum()
      #Vebmap<[capacity = 4, elements = [{0, 0}, {1, 1}, {2, 2}]]>

  As you can see, when inspecting a vebmap, you will get the capacity and the pairs of keys and values. Note that in a vebmap, the keys must be non_neg_integers and the order of the elements is determined by the keys in the order of integers rather than the hash values of the keys in maps.
  """

  defstruct veb: Veb.new(@default_limit), map: Map.new()

  @typedoc """
  As it is said in the `moduledoc`, the keys are non_neg_integers.
  """
  @type key :: non_neg_integer
  @type value :: any

  @typedoc """
  `Vebmap.t()` is the type of vebmap.
  """
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

  @doc """
  `Vebmap.new/2` provides a way to get a grand new vebmap. The two arguments determines the capacity of the new vebmap.There are three modes: `:by_max`, `:by_u` and `:by_logu` and `by_max` is set as the default mode.
  When using `:by_max`, the `limit` argument should pass the maximum value of your keys, and the program will automatically determines the least adequate capacity.
  As for `:by_u`, you should provide an nth power of 2 in the limit field which is going to be your capacity.
  And if you use `:by_logu`, please pass the maximum number of the binary bits of all your keys.

  Here are the examples:

      iex> Vebmap.new(3)
      #Vebmap<[capacity = 4, elements = []]>
      iex> Vebmap.new(8, :by_u)
      #Vebmap<[capacity = 8, elements = []]>
      iex> Vebmap.new(5, :by_logu)
      #Vebmap<[capacity = 32, elements = []]>

  """
  @spec new(non_neg_integer, :by_max | :by_u | :by_logu) :: t
  def new(limit, mode \\ :by_max) do
    %Vebmap{veb: Veb.new(limit, mode), map: Map.new()}
  end

  @doc """
  `Vebmap.delete/2` will help you delete the provided key and its value from a vebmap:

      iex> [{0, 0}, {1, 1}] |> Vebmap.from_enum() |> Vebmap.delete(0)
      #Vebmap<[capacity = 2, elements = [{1, 1}]]>
      iex> [{0, 0}, {1, 1}] |> Vebmap.from_enum() |> Vebmap.delete(2)
      #Vebmap<[capacity = 2, elements = [{0, 0}, {1, 1}]]>

  """
  @spec delete(t, key) :: t
  def delete(vebmap, key) do
    %Vebmap{veb: vebmap.veb |> Veb.delete(key), map: vebmap.map |> Map.delete(key)}
  end

  @doc """
  Drops the given value from a vebmap:
      iex> [{0, 0}, {1, 1}] |> Vebmap.from_enum() |> Vebmap.drop([0])
      #Vebmap<[capacity = 2, elements = [{1, 1}]]>
  """
  @spec drop(t, [key]) :: t
  def drop(vebmap, []), do: vebmap
  def drop(vebmap, [head | tail]), do: drop(delete(vebmap, head), tail)

  @doc """
  Check if tow given vebmap are the same one.

      iex> [{0, 0}, {1, 1}] |> Vebmap.from_enum() |> Vebmap.drop([0])
      #Vebmap<[capacity = 2, elements = [{1, 1}]]>
      iex> a = [{0, 0}, {1, 1}] |> Vebmap.from_enum()
      #Vebmap<[capacity = 2, elements = [{0, 0}, {1, 1}]]>
      iex> b = [{0, 0}, {1, 2}] |> Vebmap.from_enum()
      #Vebmap<[capacity = 2, elements = [{0, 0}, {1, 2}]]>
      iex> Vebmap.equal?(a, a)
      true
      iex> Vebmap.equal?(a, b)
      false

  """
  @spec equal?(t, t) :: boolean
  def equal?(vebmap1, vebmap2), do: Map.equal?(vebmap1.map, vebmap2.map)

  @doc """
  Fetches the value for a specific `key` in the given `vebmap`, erroring out if
  `vebmap` doesn't contain `key`.
  If `vebmap` contains the given `key`, the corresponding value is returned. If
  `vebmap` doesn't contain `key`, a `KeyError` exception is raised.
  """
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

  @doc """
  Gets the value for a specific `key` in `vebmap`.
  If `key` is present in `vebmap` with value `value`, then `value` is
  returned. Otherwise, `default` is returned (which is `nil` unless
  specified otherwise).
  """
  @spec get(t, key, value) :: value
  def get(vebmap, key, default \\ nil) do
    Map.get(vebmap.map, key, default)
  end

  @doc """
  Gets the value from `key` and updates it. Raises if there is no `key`.
  Behaves exactly like `get_and_update/3`, but raises a `KeyError` exception if
  `key` is not present in `vebmap`.
  """
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
  @doc """
  Gets the value for a specific `key` in `vebmap`.
  If `key` is present in `vebmap` with value `value`, then `value` is
  returned. Otherwise, `fun` is evaluated and its result is returned.
  This is useful if the default value is very expensive to calculate or
  generally difficult to setup and teardown again.
  """
  def get_lazy(vebmap, key, fun) when is_function(fun, 0) do
    case fetch(vebmap, key) do
      :error -> fun.()
      value -> value
    end
  end

  @doc """
  Returns whether the given `key` exists in the given `vebmap`.
  """
  @spec has_key?(t, key) :: boolean
  def has_key?(vebmap, key) do
    Map.has_key?(vebmap.map, key)
  end

  @doc """
  Returns all keys from `map`.
  """
  @spec keys(t) :: [key]
  def keys(vebmap) do
    Map.keys(vebmap.map)
  end

  @doc """
  Merges two vebmaps into one.

  All keys in vebmap2 will be added to vebmap1, overriding any existing one (i.e., the keys in vebmap2 “have precedence” over the ones in vebmap1).

  Note that if you merge two vebmaps woth different capacities then the returned vebmap will have the larger capacity.
  """
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

  @doc """
  Merges two vebmaps into one, resolving conflicts through the given fun.

  All keys in vebmap2 will be added to vebmap1. The given function will be invoked when there are duplicate keys; its arguments are key (the duplicate key), value1 (the value of key in vebmap1), and value2 (the value of key in vebmap2). The value returned by fun is used as the value under key in the resulting vebmap.
  Note that if you merge two vebmaps woth different capacities then the returned vebmap will have the larger capacity.
  """
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
  @doc """
  Construct a new vebmap from an enumerable.
  Four mode provided, `:auto` will automatically detect the largest key and determine the capacity. `:by_max`, `by_u` and `by_logu` functions the same as in `Vebmap.new/2`
  """
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
    "#Vebmap<[capacity = #{Vebmap.capacity(vebmap)}, elements = " <>
      Kernel.inspect(Vebmap.to_list(vebmap)) <> "]>"
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
