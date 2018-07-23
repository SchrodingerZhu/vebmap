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
      res -> res
    end
  end

  def fetch(vebmap, key) do
    Map.fetch(vebmap.map, key)
  end

  def get(vebmap, key, default \\ nil) do
    Map.get(vebmap, key, default)
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
    the_keys = keys(vebmap2)
    %Vebmap{veb: put_keys(vebmap1.veb, the_keys), map: map}
  end

  defp put_keys(veb, []), do: veb
  defp put_keys(veb, [head | tail]), do: put_keys(Veb.insert(veb, head), tail)

  def merge(vebmap1, vebmap2, fun) do
    if vebmap1.veb.log_u >= vebmap2.veb.log_u do
      map = Map.merge(vebmap1.map, vebmap2.map, fun)
      the_keys = keys(vebmap2)
      %Vebmap{veb: put_keys(vebmap1.veb, the_keys), map: map}
    else
      merge(vebmap2, vebmap1, fun)
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
    %Vebmap{veb: Veb.insert(vebmap.veb, key), map: Map.put(vebmap.map, key, value)}
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
    map  = Map.take(vebmap.map, keys)
    %Vebmap{veb: map |> Map.keys() |> Veb.from_list(limit, mode), map: map}
  end

  def to_list(vebmap), do: Map.to_list(vebmap.map)

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


end
